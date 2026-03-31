import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58/bs58.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solfare/core/constant/solana_path.dart';
import 'package:solfare/core/error/exception.dart';
import 'package:solfare/features/wallet/data/model/wallet_model.dart';

/// Handles all local wallet operations:
/// - Mnemonic generation
/// - Key derivation (Ed25519 via Solana's BIP-44 path)
/// - Secure storage read/write
abstract class WalletLocalDataSource {
  /// Generate a brand new wallet from a fresh mnemonic.
  Future<WalletModel> createWallet();

  /// Derive a wallet from an existing mnemonic phrase.
  Future<WalletModel> deriveWallet(String mnemonic);

  /// Save wallet credentials to secure storage.
  Future<void> saveWallet(WalletModel wallet);

  /// Check if a wallet is stored on device.
  Future<bool> hasWallet();

  /// Get the stored wallet address.
  Future<String?> getSavedAddress();

  /// Clear all wallet data from secure storage.
  Future<void> clearWallet();
}

class WalletLocalDataSourceImpl implements WalletLocalDataSource {
  final FlutterSecureStorage _secureStorage;

  static const _mnemonicKey = 'wallet_mnemonic';
  static const _addressKey = 'wallet_address';

  WalletLocalDataSourceImpl({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  @override
  Future<WalletModel> createWallet() async {
    try {
      final mnemonic = bip39.generateMnemonic();
      return deriveWallet(mnemonic);
    } catch (e) {
      throw KeyDerivationException('Failed to create wallet: $e');
    }
  }

  @override
  Future<WalletModel> deriveWallet(String mnemonic) async {
    try {
      if (!bip39.validateMnemonic(mnemonic)) {
        throw const KeyDerivationException('Invalid mnemonic phrase');
      }

      // Mnemonic → 64-byte seed
      final seed = bip39.mnemonicToSeed(mnemonic);

      // Seed → Ed25519 key via Solana derivation path
      final keyData = await ED25519_HD_KEY.derivePath(
        SolanaPath.defaultPath,
        seed,
      );

      final privateKeyBytes = keyData.key;

      // Derive the public key from the private key
      final publicKeyList = await ED25519_HD_KEY.getPublicKey(privateKeyBytes);
      var publicKey = Uint8List.fromList(publicKeyList);

      // Handle case where library returns 33 bytes (with prefix byte)
      // Ed25519 public keys should be 32 bytes, so take the last 32 bytes if 33
      if (publicKey.length == 33) {
        // Take the last 32 bytes (skip the first byte which is likely a prefix)
        publicKey = publicKey.sublist(1);
      } else if (publicKey.length != 32) {
        // If it's not 32 or 33 bytes, something is wrong
        throw KeyDerivationException(
          'Invalid public key length: ${publicKey.length} bytes, expected 32 bytes. This may indicate a corrupted key derivation.',
        );
      }

      // Public key → Base58-encoded Solana address
      final address = base58.encode(publicKey);
      
      // Validate address decodes back to 32 bytes
      try {
        final decodedBytes = base58.decode(address);
        if (decodedBytes.length != 32) {
          throw KeyDerivationException(
            'Address validation failed: decoded length is ${decodedBytes.length} bytes, expected 32 bytes',
          );
        }
      } catch (e) {
        if (e is KeyDerivationException) rethrow;
        throw KeyDerivationException('Failed to validate address: $e');
      }

      return WalletModel.fromKeyData(
        address: address,
        publicKey: publicKey,
        mnemonic: mnemonic,
      );
    } catch (e) {
      if (e is KeyDerivationException) rethrow;
      throw KeyDerivationException('Failed to derive wallet: $e');
    }
  }

  @override
  Future<void> saveWallet(WalletModel wallet) async {
    try {
      // Validate public key is exactly 32 bytes (Ed25519 standard)
      if (wallet.publicKey.length != 32) {
        throw LocalStorageException(
          'Invalid public key: length is ${wallet.publicKey.length} bytes, expected 32 bytes',
        );
      }
      
      // Validate address decodes to 32 bytes
      try {
        final decodedBytes = base58.decode(wallet.address);
        if (decodedBytes.length != 32) {
          throw LocalStorageException(
            'Invalid address: decoded length is ${decodedBytes.length} bytes, expected 32 bytes',
          );
        }
      } catch (e) {
        if (e is LocalStorageException) rethrow;
        throw LocalStorageException('Invalid address format: $e');
      }
      
      await _secureStorage.write(key: _mnemonicKey, value: wallet.mnemonic);
      await _secureStorage.write(key: _addressKey, value: wallet.address);
    } catch (e) {
      if (e is LocalStorageException) rethrow;
      throw LocalStorageException('Failed to save wallet: $e');
    }
  }

  @override
  Future<bool> hasWallet() async {
    try {
      // Check both mnemonic and address exist and are valid
      final mnemonic = await _secureStorage.read(key: _mnemonicKey);
      final address = await _secureStorage.read(key: _addressKey);
      
      // Both must exist and be non-empty
      if (mnemonic == null || mnemonic.isEmpty) {
        return false;
      }
      
      if (address == null || address.isEmpty) {
        return false;
      }
      
      // Validate mnemonic format (should be 12 or 24 words)
      final words = mnemonic.trim().split(RegExp(r'\s+'));
      if (words.length != 12 && words.length != 24) {
        // Invalid mnemonic format - treat as no wallet
        return false;
      }
      
      // Validate address format (should be base58, 32-50 chars)
      final trimmedAddress = address.trim();
      if (trimmedAddress.length < 32 || trimmedAddress.length > 50) {
        // Invalid address format - treat as no wallet
        return false;
      }
      
      // Both exist and appear valid
      return true;
    } catch (e) {
      // If any error occurs, treat as no wallet (safer default)
      return false;
    }
  }

  @override
  Future<String?> getSavedAddress() async {
    try {
      return await _secureStorage.read(key: _addressKey);
    } catch (e) {
      throw LocalStorageException('Failed to read address: $e');
    }
  }

  @override
  Future<void> clearWallet() async {
    try {
      // Delete all wallet-related keys from secure storage
      await _secureStorage.delete(key: _mnemonicKey);
      await _secureStorage.delete(key: _addressKey);
    } catch (e) {
      throw LocalStorageException('Failed to clear wallet: $e');
    }
  }
}
