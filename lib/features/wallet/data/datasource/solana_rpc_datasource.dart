import 'dart:convert';
import 'package:bs58/bs58.dart';
import 'package:http/http.dart' as http;
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/network/http_retry.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/wallet/data/model/transaction_model.dart';
import 'package:solfare/features/wallet/domain/entities/nft.dart';
import 'package:solfare/features/wallet/domain/entities/spl_token.dart';
import 'package:solfare/features/wallet/domain/entities/transactions.dart' show TransactionKind;

/// Data source for Solana RPC calls
/// Handles communication with Solana blockchain
abstract class SolanaRpcDataSource {
  Future<String> requestAirdrop(String address, int lamports);
  Future<int> getBalance(String address);
  Future<List<TransactionModel>> getTransactionHistory(String address, {int limit});
  Future<Map<String, dynamic>> getLatestBlockhash();
  Future<String> sendTransaction(String signedTransaction);
  Future<List<Nft>> getNfts(String address);
  Future<Nft?> getAssetByMint(String mint);
  Future<List<SplToken>> getTokens(String address);
  Future<List<Map<String, dynamic>>> getStakeAccounts(String address);
  Future<List<Map<String, dynamic>>> getVoteAccounts();
  Future<int> getMinimumBalanceForRentExemption(int dataLength);
}

class SolanaRpcDataSourceImpl implements SolanaRpcDataSource {
  // Always reads the current network URL — no restart needed on switch
  String get rpcUrl => NetworkConstants.solanaUrl;
  final http.Client client;

  SolanaRpcDataSourceImpl({
    http.Client? client,
  })  : client = client ?? http.Client();

  /// Validate a Solana address and return the cleaned version
  String _validateAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      throw Exception('Address cannot be empty');
    }

    final clean = trimmed.replaceAll(RegExp(r'[^\x20-\x7E]'), '');

    if (clean.length < 32 || clean.length > 50) {
      throw Exception('Invalid address format: length must be 32-50 characters (got ${clean.length})');
    }

    final base58Regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
    if (!base58Regex.hasMatch(clean)) {
      throw Exception('Invalid address: must contain only base58 characters');
    }

    final decodedBytes = base58.decode(clean);
    if (decodedBytes.length != 32) {
      throw Exception('Invalid address: decoded length is ${decodedBytes.length} bytes, expected 32');
    }

    return clean;
  }

  Future<dynamic> _rpcCall(String method, List<dynamic> params) async {
    final requestBody = jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': method,
      'params': params,
    });

    final response = await HttpRetry.send(
      () => client.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        throw Exception('$method failed: ${data['error']['message']}');
      }
      return data['result'];
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  @override
  Future<String> requestAirdrop(String address, int lamports) async {
    try {
      final cleanAddress = _validateAddress(address);
      final result = await _rpcCall('requestAirdrop', [cleanAddress, lamports]);
      return result as String;
    } catch (e) {
      throw Exception('Failed to request airdrop: $e');
    }
  }

  @override
  Future<int> getBalance(String address) async {
    try {
      final cleanAddress = _validateAddress(address);
      // Use 'confirmed' to match the commitment level at which the WS fires
      // accountNotification. With the default 'finalized' level the RPC
      // returns the pre-tx balance for several seconds after a send.
      final result = await _rpcCall('getBalance', [
        cleanAddress,
        {'commitment': 'confirmed'},
      ]);
      return result['value'] as int;
    } catch (e) {
      throw Exception('Failed to get balance: $e');
    }
  }

  @override
  Future<List<TransactionModel>> getTransactionHistory(String address, {int limit = 20}) async {
    try {
      final cleanAddress = _validateAddress(address);

      final signatures = await _rpcCall('getSignaturesForAddress', [
        cleanAddress,
        {'limit': limit},
      ]);

      if (signatures is! List || signatures.isEmpty) return [];

      final List<TransactionModel> transactions = [];

      for (final sig in signatures) {
        try {
          final signature = sig['signature'] as String;
          final txResult = await _rpcCall('getTransaction', [
            signature,
            {'encoding': 'jsonParsed', 'maxSupportedTransactionVersion': 0},
          ]);

          if (txResult == null) continue;

          final meta = txResult['meta'];
          final transaction = txResult['transaction'];
          final message = transaction['message'];
          final accountKeys = message['accountKeys'] as List;

          // accountKeys entries can be either strings or {pubkey: ...} objects
          // depending on the encoding the RPC chose for that tx.
          String sender = '';
          String receiver = '';
          if (accountKeys.isNotEmpty) {
            sender = accountKeys[0] is String
                ? accountKeys[0]
                : accountKeys[0]['pubkey'] ?? '';
          }
          if (accountKeys.length > 1) {
            receiver = accountKeys[1] is String
                ? accountKeys[1]
                : accountKeys[1]['pubkey'] ?? '';
          }

          final preBalances = meta['preBalances'] as List;
          final postBalances = meta['postBalances'] as List;
          final fee = meta['fee'] as int;
          final amount = (preBalances[0] as int) - (postBalances[0] as int) - fee;

          final blockTime = txResult['blockTime'] as int?;
          final timestamp = blockTime != null
              ? DateTime.fromMillisecondsSinceEpoch(blockTime * 1000)
              : DateTime.now();

          final status = meta['err'] == null ? 'success' : 'failed';

          // An NFT transfer moves exactly 1 unit of a mint with decimals=0.
          final nftTransfer = _detectNftTransfer(meta, cleanAddress);
          if (nftTransfer != null) {
            final nft = await getAssetByMint(nftTransfer.mint);
            if (nft != null) {
              transactions.add(TransactionModel(
                signature: signature,
                sender: nftTransfer.from,
                receiver: nftTransfer.to,
                amount: 0,
                transactionFee: fee,
                timestamp: timestamp,
                status: status,
                kind: TransactionKind.nft,
                nft: nft,
              ));
              debugLog('[RPC] Parsed NFT tx: ${signature.substring(0, 8)}... | ${nft.name}');
              continue;
            }
          }

          transactions.add(TransactionModel(
            signature: signature,
            sender: sender,
            receiver: receiver,
            amount: amount.abs(),
            transactionFee: fee,
            timestamp: timestamp,
            status: status,
          ));

          debugLog('[RPC] Parsed tx: ${signature.substring(0, 8)}... | ${amount.abs()} lamports | $status');
        } catch (e) {
          debugLog('[RPC] Failed to parse transaction: $e');
          continue;
        }
      }

      debugLog('[RPC] Successfully parsed ${transactions.length} transactions');
      return transactions;
    } catch (e) {
      throw Exception('Failed to get transaction history: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getLatestBlockhash() async {
    try {
      final result = await _rpcCall('getLatestBlockhash', [
        {'commitment': 'finalized'},
      ]);
      return {
        'blockhash': result['value']['blockhash'] as String,
        'lastValidBlockHeight': result['value']['lastValidBlockHeight'] as int,
      };
    } catch (e) {
      throw Exception('Failed to get latest blockhash: $e');
    }
  }

  @override
  Future<String> sendTransaction(String signedTransaction) async {
    try {
      debugLog('[RPC] Sending transaction...');
      final result = await _rpcCall('sendTransaction', [
        signedTransaction,
        {'encoding': 'base64'},
      ]);
      debugLog('[RPC] Transaction sent! Signature: $result');
      return result as String;
    } catch (e) {
      throw Exception('Failed to send transaction: $e');
    }
  }

  @override
  Future<List<Nft>> getNfts(String address) async {
    final validAddress = _validateAddress(address);

    try {
      // Helius DAS getAssetsByOwner returns regular + compressed NFTs with metadata.
      final response = await HttpRetry.send(
        () => client.post(
          Uri.parse(NetworkConstants.heliusDasUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 'solfare-nfts',
            'method': 'getAssetsByOwner',
            'params': {
              'ownerAddress': validAddress,
              'page': 1,
              'limit': 1000,
              'displayOptions': {'showUnverifiedCollections': true},
            },
          }),
        ),
      );

      if (response.statusCode != 200) {
        debugLog('[RPC] Helius DAS HTTP ${response.statusCode}: ${response.body}');
        return [];
      }

      final body = jsonDecode(response.body);
      if (body['error'] != null) {
        debugLog('[RPC] Helius DAS error: ${body['error']}');
        return [];
      }

      final items = (body['result']?['items'] as List?) ?? [];
      return items
          .map((item) => _nftFromDasAsset(item as Map<String, dynamic>))
          .whereType<Nft>()
          .toList();
    } catch (e) {
      debugLog('[RPC] Failed to fetch NFTs: $e');
      return [];
    }
  }

  @override
  Future<List<SplToken>> getTokens(String address) async {
    final validAddress = _validateAddress(address);

    try {
      // Helius DAS getAssetsByOwner with showFungible=true returns SPL tokens
      // with balance + price data in token_info. One call covers every token
      // the user holds including Token-2022.
      final response = await HttpRetry.send(
        () => client.post(
          Uri.parse(NetworkConstants.heliusDasUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 'solfare-tokens',
            'method': 'getAssetsByOwner',
            'params': {
              'ownerAddress': validAddress,
              'page': 1,
              'limit': 1000,
              'displayOptions': {'showFungible': true},
            },
          }),
        ),
      );

      if (response.statusCode != 200) {
        debugLog('[RPC] Helius tokens HTTP ${response.statusCode}: ${response.body}');
        return [];
      }

      final body = jsonDecode(response.body);
      if (body['error'] != null) {
        debugLog('[RPC] Helius tokens error: ${body['error']}');
        return [];
      }

      final items = (body['result']?['items'] as List?) ?? [];
      return items
          .map((item) => _tokenFromDasAsset(item as Map<String, dynamic>))
          .whereType<SplToken>()
          .toList();
    } catch (e) {
      debugLog('[RPC] Failed to fetch tokens: $e');
      return [];
    }
  }

  /// Map a DAS asset payload to a SplToken. Returns null for non-fungible
  /// assets and for tokens with a zero balance (to keep the list tidy).
  SplToken? _tokenFromDasAsset(Map<String, dynamic> asset) {
    final interface = asset['interface'] as String? ?? '';
    if (!interface.contains('Fungible')) return null;

    final tokenInfo = asset['token_info'] as Map<String, dynamic>?;
    if (tokenInfo == null) return null;

    final rawBalance = tokenInfo['balance'];
    final balanceInt = rawBalance is int
        ? rawBalance
        : int.tryParse(rawBalance?.toString() ?? '0') ?? 0;
    if (balanceInt <= 0) return null;

    final decimals = tokenInfo['decimals'] as int? ?? 0;
    final balance = balanceInt / _pow10(decimals);

    final mint = asset['id'] as String?;
    if (mint == null) return null;

    final content = asset['content'] as Map<String, dynamic>?;
    final metadata = content?['metadata'] as Map<String, dynamic>?;
    final name = metadata?['name'] as String? ??
        tokenInfo['symbol'] as String? ??
        'Unknown token';
    final symbol = tokenInfo['symbol'] as String? ??
        metadata?['symbol'] as String? ??
        '';

    String? imageUrl;
    final files = content?['files'] as List?;
    if (files != null && files.isNotEmpty) {
      final first = files.first as Map<String, dynamic>?;
      imageUrl = (first?['uri'] ?? first?['cdn_uri']) as String?;
    }
    imageUrl ??= (content?['links'] as Map<String, dynamic>?)?['image'] as String?;
    imageUrl = _normalizeImageUri(imageUrl);

    final priceInfo = tokenInfo['price_info'] as Map<String, dynamic>?;
    final priceUsd = (priceInfo?['price_per_token'] as num?)?.toDouble() ?? 0;

    return SplToken(
      mint: mint,
      name: name,
      symbol: symbol,
      imageUrl: imageUrl,
      balance: balance,
      decimals: decimals,
      priceUsd: priceUsd,
    );
  }

  double _pow10(int exp) {
    var v = 1.0;
    for (var i = 0; i < exp; i++) {
      v *= 10;
    }
    return v;
  }

  /// Map a DAS asset payload to our Nft entity. Filters out non-NFT assets
  /// (fungible tokens) by interface type.
  Nft? _nftFromDasAsset(Map<String, dynamic> asset) {
    final interface = asset['interface'] as String? ?? '';
    // Interfaces for NFTs: V1_NFT, V2_NFT, ProgrammableNFT, LEGACY_NFT, MplCoreAsset.
    // Exclude: FungibleToken, FungibleAsset.
    if (interface.contains('Fungible')) return null;

    final mint = asset['id'] as String?;
    if (mint == null) return null;

    final content = asset['content'] as Map<String, dynamic>?;
    final metadata = content?['metadata'] as Map<String, dynamic>?;
    final name = metadata?['name'] as String? ?? 'Unnamed NFT';
    final description = metadata?['description'] as String?;

    // Image: prefer animated variants (gif/webp) when multiple files are listed,
    // fall back to any static image. Use origin `uri` over Helius `cdn_uri` —
    // the CDN's on-the-fly resize frequently returns 524 (Cloudflare timeout).
    String? imageUrl;
    final files = content?['files'] as List?;
    if (files != null) {
      final candidates = <Map<String, dynamic>>[];
      for (final f in files) {
        final file = f as Map<String, dynamic>?;
        if (file == null) continue;
        final mime = (file['mime'] as String? ?? '').toLowerCase();
        final uri = (file['uri'] ?? file['cdn_uri']) as String?;
        if (uri == null) continue;
        final isImage = mime.startsWith('image') || mime.isEmpty;
        if (!isImage) continue;
        candidates.add({'mime': mime, 'uri': uri});
      }
      int rank(String mime) {
        if (mime.contains('gif')) return 0;
        if (mime.contains('webp')) return 1;
        if (mime.startsWith('image')) return 2;
        return 3;
      }
      candidates.sort((a, b) => rank(a['mime'] as String).compareTo(rank(b['mime'] as String)));
      if (candidates.isNotEmpty) imageUrl = candidates.first['uri'] as String?;
    }
    // Metaplex off-chain metadata often exposes an animation_url separate from
    // the static image — honour it when present.
    final animationUrl = metadata?['animation_url'] as String?;
    if (animationUrl != null && _looksAnimated(animationUrl)) {
      imageUrl = animationUrl;
    }
    imageUrl ??= (content?['links'] as Map<String, dynamic>?)?['image'] as String?;
    imageUrl ??= metadata?['image'] as String?;
    imageUrl = _normalizeImageUri(imageUrl);
    debugLog('[NFT] $name | image=$imageUrl');

    final grouping = asset['grouping'] as List?;
    String? collection;
    if (grouping != null) {
      for (final g in grouping) {
        if ((g as Map)['group_key'] == 'collection') {
          collection = g['group_value'] as String?;
          break;
        }
      }
    }

    return Nft(
      mint: mint,
      name: name,
      imageUrl: imageUrl,
      collection: collection,
      description: description,
    );
  }

  /// Inspect a parsed transaction's token balance deltas to find an NFT
  /// transfer involving [owner]. Returns null if none found. An NFT is
  /// identified by decimals=0 and a balance change of exactly 1 unit.
  _NftTransferInfo? _detectNftTransfer(dynamic meta, String owner) {
    final preBalances = (meta['preTokenBalances'] as List?) ?? const [];
    final postBalances = (meta['postTokenBalances'] as List?) ?? const [];
    if (preBalances.isEmpty && postBalances.isEmpty) return null;

    // Index balances by (accountIndex, mint) so we can diff pre vs post.
    // Map key: "$accountIndex|$mint" -> {owner, amount, decimals}
    Map<String, Map<String, dynamic>> indexBy(List balances) {
      final out = <String, Map<String, dynamic>>{};
      for (final b in balances) {
        final m = b as Map<String, dynamic>;
        final key = '${m['accountIndex']}|${m['mint']}';
        out[key] = m;
      }
      return out;
    }

    final pre = indexBy(preBalances);
    final post = indexBy(postBalances);
    final keys = {...pre.keys, ...post.keys};

    String? mint;
    String? fromOwner;
    String? toOwner;
    int ownerDelta = 0;

    for (final key in keys) {
      final p = pre[key];
      final q = post[key];
      final decimals = (q?['uiTokenAmount']?['decimals'] ?? p?['uiTokenAmount']?['decimals']) as int? ?? 0;
      if (decimals != 0) continue;

      final preAmount = int.tryParse(p?['uiTokenAmount']?['amount']?.toString() ?? '0') ?? 0;
      final postAmount = int.tryParse(q?['uiTokenAmount']?['amount']?.toString() ?? '0') ?? 0;
      final delta = postAmount - preAmount;
      if (delta == 0) continue;
      if (delta.abs() != 1) continue; // NFTs move in units of 1

      final thisOwner = (q?['owner'] ?? p?['owner']) as String?;
      final thisMint = (q?['mint'] ?? p?['mint']) as String?;
      if (thisOwner == null || thisMint == null) continue;

      mint ??= thisMint;
      if (thisMint != mint) continue; // only track one NFT per tx

      if (delta > 0) {
        toOwner = thisOwner;
      } else {
        fromOwner = thisOwner;
      }
      if (thisOwner == owner) ownerDelta += delta;
    }

    if (mint == null || ownerDelta == 0) return null;

    return _NftTransferInfo(
      mint: mint,
      from: fromOwner ?? '',
      to: toOwner ?? '',
    );
  }

  /// Fetch a single asset by mint — used by transaction history to attach NFT
  /// metadata to detected SPL transfers. Returns null on failure.
  @override
  Future<Nft?> getAssetByMint(String mint) async {
    try {
      final response = await HttpRetry.send(
        () => client.post(
          Uri.parse(NetworkConstants.heliusDasUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 'solfare-nft-one',
            'method': 'getAsset',
            'params': {'id': mint},
          }),
        ),
      );
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      final asset = body['result'] as Map<String, dynamic>?;
      if (asset == null) return null;
      return _nftFromDasAsset(asset);
    } catch (_) {
      return null;
    }
  }

  /// True if [uri]'s extension suggests an animated image that Flutter's
  /// Image.network can render (gif, animated webp). Videos (mp4/webm) are
  /// excluded since they need video_player.
  bool _looksAnimated(String uri) {
    final lower = uri.toLowerCase().split('?').first;
    return lower.endsWith('.gif') || lower.endsWith('.webp');
  }

  /// Rewrite ipfs:// and ar:// URIs to public HTTPS gateways so Image.network can load them.
  String? _normalizeImageUri(String? uri) {
    if (uri == null || uri.isEmpty) return null;
    final trimmed = uri.trim();
    if (trimmed.startsWith('ipfs://')) {
      final path = trimmed.substring('ipfs://'.length).replaceFirst(RegExp(r'^ipfs/'), '');
      return 'https://ipfs.io/ipfs/$path';
    }
    if (trimmed.startsWith('ar://')) {
      return 'https://arweave.net/${trimmed.substring('ar://'.length)}';
    }
    return trimmed;
  }

  @override
  Future<List<Map<String, dynamic>>> getStakeAccounts(String address) async {
    try {
      final cleanAddress = _validateAddress(address);
      final result = await _rpcCall('getProgramAccounts', [
        'Stake11111111111111111111111111111111111111',
        {
          'encoding': 'jsonParsed',
          'filters': [
            {
              'memcmp': {
                'offset': 12,
                'bytes': cleanAddress,
              },
            },
          ],
        },
      ]);

      final accounts = (result as List?) ?? [];
      final List<Map<String, dynamic>> stakeAccounts = [];

      for (final account in accounts) {
        final pubkey = account['pubkey'] as String;
        final lamports = account['account']['lamports'] as int;
        final parsed = account['account']['data']['parsed'];
        final info = parsed['info'] as Map<String, dynamic>;
        final stake = info['stake'] as Map<String, dynamic>?;
        final delegation = stake?['delegation'] as Map<String, dynamic>?;

        stakeAccounts.add({
          'pubkey': pubkey,
          'lamports': lamports,
          'voterPubkey': delegation?['voter'] as String?,
          'activationEpoch': int.tryParse(delegation?['activationEpoch']?.toString() ?? '0') ?? 0,
          'deactivationEpoch': int.tryParse(delegation?['deactivationEpoch']?.toString() ?? '0') ?? 0,
        });
      }

      return stakeAccounts;
    } catch (e) {
      throw Exception('Failed to get stake accounts: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getVoteAccounts() async {
    try {
      final result = await _rpcCall('getVoteAccounts', []);
      final current = (result['current'] as List?) ?? [];

      return current.map<Map<String, dynamic>>((v) => {
        'votePubkey': v['votePubkey'] as String,
        'activatedStake': v['activatedStake'] as int,
        'commission': v['commission'] as int,
      }).toList();
    } catch (e) {
      throw Exception('Failed to get vote accounts: $e');
    }
  }

  @override
  Future<int> getMinimumBalanceForRentExemption(int dataLength) async {
    try {
      final result = await _rpcCall('getMinimumBalanceForRentExemption', [dataLength]);
      return result as int;
    } catch (e) {
      throw Exception('Failed to get minimum balance for rent exemption: $e');
    }
  }
}

class _NftTransferInfo {
  final String mint;
  final String from;
  final String to;
  const _NftTransferInfo({required this.mint, required this.from, required this.to});
}
