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
      final publicKey = await ED25519_HD_KEY.getPublicKey(privateKeyBytes);

      // Public key → Base58-encoded Solana address
      final address = base58.encode(Uint8List.fromList(publicKey));

      return WalletModel.fromKeyData(
        address: address,
        publicKey: Uint8List.fromList(publicKey),
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
      await _secureStorage.write(key: _mnemonicKey, value: wallet.mnemonic);
      await _secureStorage.write(key: _addressKey, value: wallet.address);
    } catch (e) {
      throw LocalStorageException('Failed to save wallet: $e');
    }
  }

  @override
  Future<bool> hasWallet() async {
    try {
      final mnemonic = await _secureStorage.read(key: _mnemonicKey);
      return mnemonic != null && mnemonic.isNotEmpty;
    } catch (e) {
      throw LocalStorageException('Failed to check wallet: $e');
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
}
