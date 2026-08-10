import 'dart:convert';
import 'package:bs58/bs58.dart';
import 'package:http/http.dart' as http;
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/network/http_retry.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/core/util/json.dart';
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
  Future<Map<String, dynamic>> getLatestBlockhash({String commitment});
  Future<String> sendTransaction(String signedTransaction, {bool skipPreflight});
  Future<List<Nft>> getNfts(String address);
  Future<Nft?> getAssetByMint(String mint);
  Future<List<SplToken>> getTokens(String address);
  Future<List<Map<String, dynamic>>> getStakeAccounts(String address);
  Future<List<Map<String, dynamic>>> getVoteAccounts();
  Future<int> getMinimumBalanceForRentExemption(int dataLength);

  // ── Transaction lifecycle ──

  /// Micro-lamports per compute unit paid in recent slots by transactions
  /// touching [writableAccounts]. Empty means the fee market is idle.
  Future<List<int>> getRecentPrioritizationFees(List<String> writableAccounts);

  /// Dry-run against the current bank. Returns the raw `value`:
  /// `{err, logs, unitsConsumed, preBalances, postBalances, ...}`.
  Future<Map<String, dynamic>> simulateTransaction(String base64Tx, {bool innerInstructions});

  /// Null if the cluster has never seen [signature] — dropped, or not yet
  /// propagated.
  Future<Map<String, dynamic>?> getSignatureStatus(String signature);

  /// Program log lines for a landed transaction. `getSignatureStatuses`
  /// reports that a transaction failed but never why; the logs are the only
  /// place the reason is written down.
  Future<List<String>> getTransactionLogs(String signature);

  /// Compared against a blockhash's lastValidBlockHeight to detect expiry.
  Future<int> getBlockHeight();

  /// jsonParsed account data, or null when the account does not exist.
  Future<Map<String, dynamic>?> getAccountInfo(String address);

  /// Expiry check for transactions we didn't build and have no block
  /// height for.
  Future<bool> isBlockhashValid(String blockhash);

  /// UI balance [owner] holds of [mint], summed across their token accounts.
  /// Zero when they hold none.
  Future<double> getTokenBalance(String owner, String mint);

  /// Current epoch — decides which of a Token-2022 mint's two transfer fee
  /// schedules is in force.
  Future<int> getEpoch();
}

class SolanaRpcDataSourceImpl implements SolanaRpcDataSource {
  // Always reads the current network URL — no restart needed on switch
  String get rpcUrl => NetworkConstants.solanaUrl;
  final http.Client client;

  SolanaRpcDataSourceImpl({
    http.Client? client,
  })  : client = client ?? http.Client();

  // Validate a Solana address and return the cleaned version
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
      // Typed all the way down. A JSON-RPC envelope that is not an object,
      // or an error member that is not one, used to reach `['message']` as a
      // dynamic call and throw a NoSuchMethodError in place of the error it
      // was trying to report.
      final data = asJsonMap(jsonDecode(response.body));
      if (data == null) {
        throw Exception('$method returned something that is not a JSON object');
      }
      final error = data.mapAt('error');
      if (error != null) {
        throw Exception('$method failed: ${error.stringAt('message') ?? error}');
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
      return asJsonMap(result)?.intAt('value') ?? 0;
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
          final signature = asJsonMap(sig)?.stringAt('signature');
          if (signature == null) continue;
          final txResult = await _rpcCall('getTransaction', [
            signature,
            {'encoding': 'jsonParsed', 'maxSupportedTransactionVersion': 0},
          ]);

          final tx = asJsonMap(txResult);
          if (tx == null) continue;

          final meta = tx.mapAt('meta');
          final message = tx.mapAt('transaction')?.mapAt('message');
          if (meta == null || message == null) continue;
          final accountKeys = message.listAt('accountKeys') ?? const [];

          // accountKeys entries can be either strings or {pubkey: ...} objects
          // depending on the encoding the RPC chose for that tx.
          String keyAt(int index) {
            if (index >= accountKeys.length) return '';
            final entry = accountKeys[index];
            if (entry is String) return entry;
            return asJsonMap(entry)?.stringAt('pubkey') ?? '';
          }

          final sender = keyAt(0);
          final receiver = keyAt(1);

          final preBalances = meta.listAt('preBalances') ?? const [];
          final postBalances = meta.listAt('postBalances') ?? const [];
          final fee = meta.intAt('fee') ?? 0;
          if (preBalances.isEmpty || postBalances.isEmpty) continue;
          final pre = preBalances[0];
          final post = postBalances[0];
          if (pre is! int || post is! int) continue;
          final amount = pre - post - fee;

          final blockTime = tx.intAt('blockTime');
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

  /// Defaults to `confirmed` — a finalized blockhash is already ~32 slots
  /// into its 150-block validity window.
  @override
  Future<Map<String, dynamic>> getLatestBlockhash({String commitment = 'confirmed'}) async {
    try {
      final result = await _rpcCall('getLatestBlockhash', [
        {'commitment': commitment},
      ]);
      final value = asJsonMap(result)?.mapAt('value');
      final blockhash = value?.stringAt('blockhash');
      final lastValid = value?.intAt('lastValidBlockHeight');
      if (blockhash == null || lastValid == null) {
        throw Exception('getLatestBlockhash returned an unusable value');
      }
      return {'blockhash': blockhash, 'lastValidBlockHeight': lastValid};
    } catch (e) {
      throw Exception('Failed to get latest blockhash: $e');
    }
  }

  /// [skipPreflight] on rebroadcasts: preflight re-simulates against a bank
  /// where the tx already landed and rejects it as AlreadyProcessed.
  @override
  Future<String> sendTransaction(String signedTransaction, {bool skipPreflight = false}) async {
    try {
      final result = await _rpcCall('sendTransaction', [
        signedTransaction,
        {
          'encoding': 'base64',
          'skipPreflight': skipPreflight,
          'preflightCommitment': 'confirmed',
          // We own the rebroadcast loop; the node's blind retry would only
          // duplicate traffic.
          'maxRetries': 0,
        },
      ]);
      debugLog('[RPC] Transaction sent! Signature: $result');
      return result as String;
    } catch (e) {
      throw Exception('Failed to send transaction: $e');
    }
  }

  @override
  Future<List<int>> getRecentPrioritizationFees(List<String> writableAccounts) async {
    try {
      // The RPC caps the address list at 128; beyond that it errors outright.
      final addresses = writableAccounts.take(128).toList();
      final result = await _rpcCall('getRecentPrioritizationFees', [addresses]);
      final entries = (result as List?) ?? const [];
      return entries
          .map((e) => (e as Map)['prioritizationFee'])
          .whereType<int>()
          .toList();
    } catch (e) {
      debugLog('[RPC] Prioritization fee lookup failed: $e');
      return const [];
    }
  }

  @override
  Future<Map<String, dynamic>> simulateTransaction(
    String base64Tx, {
    bool innerInstructions = false,
  }) async {
    final result = await _rpcCall('simulateTransaction', [
      base64Tx,
      {
        'encoding': 'base64',
        'commitment': 'confirmed',
        // CPI is where a transfer hides — the preview needs to see it.
        if (innerInstructions) 'innerInstructions': true,
        // The probe carries a signature over a blockhash the simulator will
        // swap out, so signature verification would necessarily fail.
        'sigVerify': false,
        'replaceRecentBlockhash': true,
      },
    ]);
    final value = asJsonMap(result)?.mapAt('value');
    if (value == null) {
      throw Exception('simulateTransaction returned no value');
    }
    return value;
  }

  @override
  Future<Map<String, dynamic>?> getSignatureStatus(String signature) async {
    final result = await _rpcCall('getSignatureStatuses', [
      [signature],
      {'searchTransactionHistory': false},
    ]);
    final values = asJsonMap(result)?.listAt('value') ?? const [];
    if (values.isEmpty) return null;
    return asJsonMap(values.first);
  }

  @override
  Future<List<String>> getTransactionLogs(String signature) async {
    try {
      final result = await _rpcCall('getTransaction', [
        signature,
        {
          'encoding': 'json',
          'commitment': 'confirmed',
          'maxSupportedTransactionVersion': 0,
        },
      ]);
      final logs = asJsonMap(result)?.mapAt('meta')?.listAt('logMessages');
      return logs?.whereType<String>().toList() ?? const [];
    } catch (e) {
      // A missing explanation is not worth failing over — the caller falls
      // back to the generic message it would have shown anyway.
      debugLog('[RPC] Could not read logs for $signature: $e');
      return const [];
    }
  }

  @override
  Future<int> getBlockHeight() async {
    final result = await _rpcCall('getBlockHeight', [
      {'commitment': 'confirmed'},
    ]);
    return result as int;
  }

  @override
  Future<int> getEpoch() async {
    final result = await _rpcCall('getEpochInfo', [
      {'commitment': 'confirmed'},
    ]);
    final epoch = asJsonMap(result)?.intAt('epoch');
    if (epoch == null) throw Exception('getEpochInfo returned no epoch');
    return epoch;
  }

  @override
  Future<double> getTokenBalance(String owner, String mint) async {
    try {
      final cleanOwner = _validateAddress(owner);
      final result = await _rpcCall('getTokenAccountsByOwner', [
        cleanOwner,
        {'mint': _validateAddress(mint)},
        {'encoding': 'jsonParsed', 'commitment': 'confirmed'},
      ]);

      // A wallet can hold the same mint in more than one account — the ATA
      // plus anything an airdrop or a program created for it.
      // Summed in base units through BigInt, not as doubles. uiAmount is a
      // JSON double and is exact only to 2^53, so a nine-decimal balance
      // above ~9,007,199 tokens loses base units — and swap_bloc converts
      // this straight back to an integer amount, where rounding up past the
      // real balance makes the route fail for no visible reason.
      var raw = BigInt.zero;
      var decimals = 0;
      for (final account in asJsonMap(result)?.listAt('value') ?? const []) {
        final amount = asJsonMap(account)
            ?.pathAt(['account', 'data', 'parsed', 'info'])
            ?.mapAt('tokenAmount');
        if (amount == null) continue;
        decimals = amount.intAt('decimals') ?? decimals;
        final units = BigInt.tryParse(amount.stringAt('amount') ?? '');
        if (units != null) raw += units;
      }
      if (raw == BigInt.zero) return 0;
      return raw / BigInt.from(10).pow(decimals);
    } catch (e) {
      debugLog('[RPC] Token balance lookup failed: $e');
      return 0;
    }
  }

  @override
  Future<bool> isBlockhashValid(String blockhash) async {
    final result = await _rpcCall('isBlockhashValid', [
      blockhash,
      {'commitment': 'confirmed'},
    ]);
    return asJsonMap(result)?.boolAt('value') ?? false;
  }

  @override
  Future<Map<String, dynamic>?> getAccountInfo(String address) async {
    final cleanAddress = _validateAddress(address);
    final result = await _rpcCall('getAccountInfo', [
      cleanAddress,
      {'encoding': 'jsonParsed', 'commitment': 'confirmed'},
    ]);
    return asJsonMap(result)?.mapAt('value');
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

      final body = asJsonMap(jsonDecode(response.body));
      if (body == null || body['error'] != null) {
        debugLog('[RPC] Helius DAS error: ${body?['error'] ?? 'unreadable body'}');
        return [];
      }

      final items = body.mapAt('result')?.listAt('items') ?? const [];
      return items
          .map(asJsonMap)
          .whereType<Map<String, dynamic>>()
          .map(_nftFromDasAsset)
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

      final body = asJsonMap(jsonDecode(response.body));
      if (body == null || body['error'] != null) {
        debugLog('[RPC] Helius tokens error: ${body?['error'] ?? 'unreadable body'}');
        return [];
      }

      final items = body.mapAt('result')?.listAt('items') ?? const [];
      return items
          .map(asJsonMap)
          .whereType<Map<String, dynamic>>()
          .map(_tokenFromDasAsset)
          .whereType<SplToken>()
          .toList();
    } catch (e) {
      debugLog('[RPC] Failed to fetch tokens: $e');
      return [];
    }
  }

  // Map a DAS asset payload to a SplToken. Returns null for non-fungible
  // assets and for tokens with a zero balance (to keep the list tidy).
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
    // A mint with no metadata has neither. Naming them all "Unknown token"
    // makes two such holdings indistinguishable in the list, so fall back to
    // the mint — which at least identifies which one is which.
    final shortMint = mint.length <= 8
        ? mint
        : '${mint.substring(0, 4)}…${mint.substring(mint.length - 4)}';
    final name = _firstNonEmpty([
          metadata?['name'] as String?,
          tokenInfo['symbol'] as String?,
        ]) ??
        shortMint;
    final symbol = _firstNonEmpty([
          tokenInfo['symbol'] as String?,
          metadata?['symbol'] as String?,
        ]) ??
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

  // First value that is present and not blank. DAS returns both null and
  // empty strings for missing metadata, and only one of those is caught by
  // a `??` chain.
  String? _firstNonEmpty(List<String?> candidates) {
    for (final value in candidates) {
      if (value != null && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  double _pow10(int exp) {
    var v = 1.0;
    for (var i = 0; i < exp; i++) {
      v *= 10;
    }
    return v;
  }

  // Map a DAS asset payload to our Nft entity. Filters out non-NFT assets
  // (fungible tokens) by interface type.
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

  // Inspect a parsed transaction's token balance deltas to find an NFT
  // transfer involving [owner]. Returns null if none found. An NFT is
  // identified by decimals=0 and a balance change of exactly 1 unit.
  _NftTransferInfo? _detectNftTransfer(Map<String, dynamic> meta, String owner) {
    final preBalances = meta.listAt('preTokenBalances') ?? const [];
    final postBalances = meta.listAt('postTokenBalances') ?? const [];
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
      final decimals =
          q?.mapAt('uiTokenAmount')?.intAt('decimals') ??
              p?.mapAt('uiTokenAmount')?.intAt('decimals') ??
              0;
      if (decimals != 0) continue;

      final preAmount =
          int.tryParse(p?.mapAt('uiTokenAmount')?.stringAt('amount') ?? '0') ?? 0;
      final postAmount =
          int.tryParse(q?.mapAt('uiTokenAmount')?.stringAt('amount') ?? '0') ?? 0;
      final delta = postAmount - preAmount;
      if (delta == 0) continue;
      if (delta.abs() != 1) continue; // NFTs move in units of 1

      final thisOwner = q?.stringAt('owner') ?? p?.stringAt('owner');
      final thisMint = q?.stringAt('mint') ?? p?.stringAt('mint');
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
      final asset = asJsonMap(jsonDecode(response.body))?.mapAt('result');
      if (asset == null) return null;
      return _nftFromDasAsset(asset);
    } catch (_) {
      return null;
    }
  }

  // True if [uri]'s extension suggests an animated image that Flutter's
  // Image.network can render (gif, animated webp). Videos (mp4/webm) are
  // excluded since they need video_player.
  bool _looksAnimated(String uri) {
    final lower = uri.toLowerCase().split('?').first;
    return lower.endsWith('.gif') || lower.endsWith('.webp');
  }

  // Rewrite ipfs:// and ar:// URIs to public HTTPS gateways so Image.network can load them.
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

      for (final entry in accounts) {
        final account = asJsonMap(entry);
        final pubkey = account?.stringAt('pubkey');
        final inner = account?.mapAt('account');
        if (pubkey == null || inner == null) continue;

        final delegation = inner
            .pathAt(['data', 'parsed', 'info'])
            ?.mapAt('stake')
            ?.mapAt('delegation');

        stakeAccounts.add({
          'pubkey': pubkey,
          'lamports': inner.intAt('lamports') ?? 0,
          'voterPubkey': delegation?.stringAt('voter'),
          // Epochs arrive as decimal strings and u64 max means "never".
          // int.tryParse returns null for a value past 2^63, so the ?? 0
          // below turned "never deactivates" into "deactivated at epoch 0".
          'activationEpoch': _epoch(delegation?['activationEpoch']),
          'deactivationEpoch': _epoch(delegation?['deactivationEpoch']),
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
      final current = asJsonMap(result)?.listAt('current') ?? const [];

      return [
        for (final entry in current)
          if (asJsonMap(entry) case final v?)
            if (v.stringAt('votePubkey') case final key?)
              {
                'votePubkey': key,
                'activatedStake': v.intAt('activatedStake') ?? 0,
                'commission': v.intAt('commission') ?? 0,
              },
      ];
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

// A stake delegation epoch.
//
// The runtime writes u64 max for "never deactivates", which is past 2^63 and
// so returns null from int.tryParse. The old `?? 0` turned that into
// "deactivated at epoch 0", which is how an actively-staked account read as
// deactivating forever.
int _epoch(Object? raw) {
  final parsed = BigInt.tryParse(raw?.toString() ?? '');
  if (parsed == null) return 0;
  return parsed.isValidInt ? parsed.toInt() : _neverEpoch;
}

// Stands in for u64 max without overflowing a Dart int.
const int _neverEpoch = 9223372036854775807;
