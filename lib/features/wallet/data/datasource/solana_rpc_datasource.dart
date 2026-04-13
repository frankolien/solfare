import 'dart:convert';
import 'package:bs58/bs58.dart';
import 'package:http/http.dart' as http;
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/features/wallet/data/model/transaction_model.dart';

/// Data source for Solana RPC calls
/// Handles communication with Solana blockchain
abstract class SolanaRpcDataSource {
  /// Request an airdrop of SOL to an address (devnet/testnet only)
  Future<String> requestAirdrop(String address, int lamports);

  /// Get the balance of a Solana address
  Future<int> getBalance(String address);

  /// Get transaction history for a Solana address
  Future<List<TransactionModel>> getTransactionHistory(String address, {int limit});

  /// Get a recent blockhash (needed to build transactions)
  Future<Map<String, dynamic>> getLatestBlockhash();

  /// Send a signed transaction (base64 encoded)
  Future<String> sendTransaction(String signedTransaction);
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

  /// Make a JSON-RPC call to the Solana node
  Future<dynamic> _rpcCall(String method, List<dynamic> params) async {
    final requestBody = jsonEncode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': method,
      'params': params,
    });

    final response = await client.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
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
      final result = await _rpcCall('getBalance', [cleanAddress]);
      return result['value'] as int;
    } catch (e) {
      throw Exception('Failed to get balance: $e');
    }
  }

  @override
  Future<List<TransactionModel>> getTransactionHistory(String address, {int limit = 20}) async {
    try {
      final cleanAddress = _validateAddress(address);

      //  Get recent transaction signatures
      print('[RPC] Fetching signatures for $cleanAddress (limit: $limit)');
      final signatures = await _rpcCall('getSignaturesForAddress', [
        cleanAddress,
        {'limit': limit},
      ]);

      if (signatures is! List || signatures.isEmpty) {
        print('[RPC] No transactions found');
        return [];
      }

      print('[RPC] Found ${signatures.length} signatures, fetching details...');

      //  Fetch full details for each transaction
      final List<TransactionModel> transactions = [];

      for (final sig in signatures) {
        try {
          final signature = sig['signature'] as String;
          final txResult = await _rpcCall('getTransaction', [
            signature,
            {'encoding': 'jsonParsed', 'maxSupportedTransactionVersion': 0},
          ]);

          if (txResult == null) continue;

          //  Parse the transaction
          final meta = txResult['meta'];
          final transaction = txResult['transaction'];
          final message = transaction['message'];
          final accountKeys = message['accountKeys'] as List;

          // Get sender and receiver addresses
          String sender = '';
          String receiver = '';
          if (accountKeys.isNotEmpty) {
            // accountKeys can be strings or objects with 'pubkey' field
            sender = accountKeys[0] is String
                ? accountKeys[0]
                : accountKeys[0]['pubkey'] ?? '';
          }
          if (accountKeys.length > 1) {
            receiver = accountKeys[1] is String
                ? accountKeys[1]
                : accountKeys[1]['pubkey'] ?? '';
          }

          // Calculate amount from balance changes
          final preBalances = meta['preBalances'] as List;
          final postBalances = meta['postBalances'] as List;
          final fee = meta['fee'] as int;
          final amount = (preBalances[0] as int) - (postBalances[0] as int) - fee;

          // Get timestamp
          final blockTime = txResult['blockTime'] as int?;
          final timestamp = blockTime != null
              ? DateTime.fromMillisecondsSinceEpoch(blockTime * 1000)
              : DateTime.now();

          // Get status
          final status = meta['err'] == null ? 'success' : 'failed';

          transactions.add(TransactionModel(
            signature: signature,
            sender: sender,
            receiver: receiver,
            amount: amount.abs(),
            transactionFee: fee,
            timestamp: timestamp,
            status: status,
          ));

          print('[RPC] Parsed tx: ${signature.substring(0, 8)}... | ${amount.abs()} lamports | $status');
        } catch (e) {
          print('[RPC] Failed to parse transaction: $e');
          continue;
        }
      }

      print('[RPC] Successfully parsed ${transactions.length} transactions');
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
      print('[RPC] Sending transaction...');
      final result = await _rpcCall('sendTransaction', [
        signedTransaction,
        {'encoding': 'base64'},
      ]);
      print('[RPC] Transaction sent! Signature: $result');
      return result as String;
    } catch (e) {
      throw Exception('Failed to send transaction: $e');
    }
  }
}
