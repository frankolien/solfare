import 'dart:convert';
import 'package:bs58/bs58.dart';
import 'package:http/http.dart' as http;
import 'package:solfare/core/constant/network.dart';

/// Data source for Solana RPC calls
/// Handles communication with Solana blockchain
abstract class SolanaRpcDataSource {
  /// Request an airdrop of SOL to an address (devnet/testnet only)
  Future<String> requestAirdrop(String address, int lamports);

  /// Get the balance of a  olana address
  Future<int> getBalance(String address);
}

class SolanaRpcDataSourceImpl implements SolanaRpcDataSource {
  final String rpcUrl;
  final http.Client client;

  SolanaRpcDataSourceImpl({
    String? rpcUrl,
    http.Client? client,
  })  : rpcUrl = rpcUrl ?? NetworkConstants.solanaUrl,
        client = client ?? http.Client();

  @override
  Future<String> requestAirdrop(String address, int lamports) async {
    try {
      // Trim whitespace and validate
      final trimmedAddress = address.trim();
      
      if (trimmedAddress.isEmpty) {
        throw Exception('Address cannot be empty');
      }
      
      // Remove any non-printable characters
      final cleanAddress = trimmedAddress.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
      
      // Solana addresses are base58-encoded, typically 32-50 characters
      if (cleanAddress.length < 32 || cleanAddress.length > 50) {
        throw Exception('Invalid address format: address length must be 32-50 characters (got ${cleanAddress.length})');
      }
      
      // Validate base58 format
      final base58Regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
      if (!base58Regex.hasMatch(cleanAddress)) {
        throw Exception('Invalid address format: address must contain only base58 characters');
      }

      // Decode and validate the address is exactly 32 bytes (Solana public key size)
      try {
        final decodedBytes = base58.decode(cleanAddress);
        if (decodedBytes.length != 32) {
          throw Exception('Invalid address: decoded length is ${decodedBytes.length} bytes, expected 32 bytes');
        }
      } catch (e) {
        if (e.toString().contains('Invalid address')) {
          rethrow;
        }
        throw Exception('Invalid address: failed to decode base58 - $e');
      }

      // Solana RPC request for airdrop
      final requestBody = jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'requestAirdrop',
        'params': [
          cleanAddress,
          lamports, // Amount in lamports (1 SOL = 1,000,000,000 lamports)
        ],
      });

      final response = await client.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception('Airdrop failed: ${data['error']['message']}');
        }
        return data['result'] as String; // Returns transaction signature
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to request airdrop: $e');
    }
  }

  @override
  Future<int> getBalance(String address) async {
    try {
      // Trim whitespace and validate
      final trimmedAddress = address.trim();
      
      if (trimmedAddress.isEmpty) {
        throw Exception('Address cannot be empty');
      }
      
      // Remove any non-printable characters
      final cleanAddress = trimmedAddress.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
      
      // Solana addresses are base58-encoded, typically 32-50 characters
      if (cleanAddress.length < 32 || cleanAddress.length > 50) {
        throw Exception('Invalid address format: address length must be 32-50 characters (got ${cleanAddress.length})');
      }
      
      // Validate base58 format
      final base58Regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
      if (!base58Regex.hasMatch(cleanAddress)) {
        throw Exception('Invalid address format: address must contain only base58 characters');
      }

      // Decode and validate the address is exactly 32 bytes (Solana public key size)
      try {
        final decodedBytes = base58.decode(cleanAddress);
        if (decodedBytes.length != 32) {
          throw Exception('Invalid address: decoded length is ${decodedBytes.length} bytes, expected 32 bytes');
        }
      } catch (e) {
        if (e.toString().contains('Invalid address')) {
          rethrow;
        }
        throw Exception('Invalid address: failed to decode base58 - $e');
      }

      // Solana RPC request for balance
      final requestBody = jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'getBalance',
        'params': [cleanAddress],
      });

      final response = await client.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['error'] != null) {
          throw Exception('Get balance failed: ${data['error']['message']}');
        }
        return data['result']['value'] as int; // Returns balance in lamports
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get balance: $e');
    }
  }
}
