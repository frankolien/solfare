import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58/bs58.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfare/core/constant/solana_path.dart';
import 'package:solfare/core/error/exception.dart';
import 'package:solfare/features/wallet/data/datasource/wallet_accounts_store.dart';
import 'package:solfare/features/wallet/data/model/wallet_model.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';

/// Handles all local wallet operations:
/// - Mnemonic generation
/// - Key derivation (Ed25519 via Solana's BIP-44 path)
/// - Secure storage read/write
///
/// Backed by [WalletAccountsStore], which stores a list of wallets. The
/// legacy single-wallet API on this interface remains and transparently
/// targets the **active** wallet.
abstract class WalletLocalDataSource {
  /// Generate a brand new wallet from a fresh mnemonic.
  Future<WalletModel> createWallet();

  /// Derive a wallet from an existing mnemonic phrase.
  Future<WalletModel> deriveWallet(String mnemonic);

  /// Save wallet credentials — installs it as a new account and marks it
  /// active. Replaces any existing wallet with the same mnemonic.
  Future<void> saveWallet(WalletModel wallet);

  /// Check if any wallet is stored on device.
  Future<bool> hasWallet();

  /// Get the active wallet's address.
  Future<String?> getSavedAddress();

  /// Wipe all stored wallet data (full factory reset).
  Future<void> clearWallet();

  /// Active wallet's mnemonic.
  Future<String?> getStoredMnemonic();

  // ── Multi-wallet API (new) ─────────────────────────────────────────────

  Future<List<WalletAccount>> getAllWallets();
  Future<WalletAccount?> getActiveWallet();
  Future<void> setActiveWalletId(String id);
  Future<WalletAccount> addWallet(String mnemonic, {String? name});
  Future<void> removeWallet(String id);
  Future<void> renameWallet(String id, String name);
  Future<void> setWalletCardBackground(String id, String cardBackground);
}

class WalletLocalDataSourceImpl implements WalletLocalDataSource {
  final FlutterSecureStorage _secureStorage;
  final WalletAccountsStore _accounts;

  /// Legacy keys, read once by the migration then deleted.
  static const _legacyMnemonicKey = 'wallet_mnemonic';
  static const _legacyAddressKey = 'wallet_address';
  static const _migrationDoneKey = 'multi_wallet_migrated_v1';

  WalletLocalDataSourceImpl({
    FlutterSecureStorage? secureStorage,
    WalletAccountsStore? accountsStore,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _accounts = accountsStore ?? WalletAccountsStore(storage: secureStorage);

  /// One-shot migration: if a legacy single wallet exists and no accounts
  /// have been installed yet, convert it into a WalletAccount entry. Runs
  /// lazily on first method call so nothing else needs to know.
  Future<void> _runMigrationIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migrationDoneKey) == true) return;

      final existing = await _accounts.loadAll();
      if (existing.isNotEmpty) {
        // Already migrated (or already multi-wallet). Mark done and move on.
        await prefs.setBool(_migrationDoneKey, true);
        return;
      }

      final legacyMnemonic = await _secureStorage.read(key: _legacyMnemonicKey);
      final legacyAddress = await _secureStorage.read(key: _legacyAddressKey);
      if (legacyMnemonic == null || legacyMnemonic.isEmpty) {
        await prefs.setBool(_migrationDoneKey, true);
        return;
      }

      // Pull the old name + card background from SharedPreferences (these
      // were stored there, not in secure storage).
      final name = prefs.getString('wallet_name') ?? 'Main Wallet';
      final card = prefs.getString('card_background') ?? 'card_1.png';

      final account = WalletAccount(
        id: WalletAccountsStore.newId(),
        address: legacyAddress ?? '',
        mnemonic: legacyMnemonic,
        name: name,
        cardBackground: card,
        createdAt: DateTime.now(),
      );
      await _accounts.saveAll([account]);
      await _accounts.setActiveId(account.id);

      // Remove the legacy keys so we don't leave plaintext-ish mnemonic
      // duplicates lying around.
      await _secureStorage.delete(key: _legacyMnemonicKey);
      await _secureStorage.delete(key: _legacyAddressKey);
      await prefs.setBool(_migrationDoneKey, true);
    } catch (_) {
      // Migration failures leave the legacy keys intact so we can retry on
      // next launch — never throw from this path.
    }
  }

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
      if (publicKey.length == 33) {
        publicKey = publicKey.sublist(1);
      } else if (publicKey.length != 32) {
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

  /// Installs a wallet by mnemonic. If a wallet with the same address is
  /// already stored, returns the existing entry instead of creating a dup.
  @override
  Future<void> saveWallet(WalletModel wallet) async {
    try {
      if (wallet.publicKey.length != 32) {
        throw LocalStorageException(
          'Invalid public key: length is ${wallet.publicKey.length} bytes, expected 32 bytes',
        );
      }
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

      await _runMigrationIfNeeded();
      await addWallet(wallet.mnemonic);
    } catch (e) {
      if (e is LocalStorageException) rethrow;
      throw LocalStorageException('Failed to save wallet: $e');
    }
  }

  @override
  Future<bool> hasWallet() async {
    try {
      await _runMigrationIfNeeded();
      final wallets = await _accounts.loadAll();
      if (wallets.isEmpty) return false;

      // Validate at least the active one looks sane.
      final active = await _accounts.getActive();
      if (active == null) return false;
      final words = active.mnemonic.trim().split(RegExp(r'\s+'));
      if (words.length != 12 && words.length != 24) return false;
      if (active.address.length < 32 || active.address.length > 50) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getSavedAddress() async {
    try {
      await _runMigrationIfNeeded();
      final active = await _accounts.getActive();
      return active?.address;
    } catch (e) {
      throw LocalStorageException('Failed to read address: $e');
    }
  }

  @override
  Future<void> clearWallet() async {
    try {
      await _accounts.wipe();
      // Belt-and-braces: clear legacy keys too.
      await _secureStorage.delete(key: _legacyMnemonicKey);
      await _secureStorage.delete(key: _legacyAddressKey);
    } catch (e) {
      throw LocalStorageException('Failed to clear wallet: $e');
    }
  }

  @override
  Future<String?> getStoredMnemonic() async {
    try {
      await _runMigrationIfNeeded();
      final active = await _accounts.getActive();
      return active?.mnemonic;
    } catch (e) {
      throw LocalStorageException('Failed to read mnemonic: $e');
    }
  }

  // ── Multi-wallet API ────────────────────────────────────────────────────

  @override
  Future<List<WalletAccount>> getAllWallets() async {
    await _runMigrationIfNeeded();
    return _accounts.loadAll();
  }

  @override
  Future<WalletAccount?> getActiveWallet() async {
    await _runMigrationIfNeeded();
    return _accounts.getActive();
  }

  @override
  Future<void> setActiveWalletId(String id) async {
    final wallets = await _accounts.loadAll();
    if (!wallets.any((w) => w.id == id)) {
      throw LocalStorageException('Unknown wallet id: $id');
    }
    await _accounts.setActiveId(id);
  }

  @override
  Future<WalletAccount> addWallet(String mnemonic, {String? name}) async {
    await _runMigrationIfNeeded();
    final model = await deriveWallet(mnemonic);
    final wallets = await _accounts.loadAll();

    // Dedupe by address.
    final existing =
        wallets.where((w) => w.address == model.address).cast<WalletAccount?>().firstWhere(
              (_) => true,
              orElse: () => null,
            );
    if (existing != null) {
      await _accounts.setActiveId(existing.id);
      return existing;
    }

    final account = WalletAccount(
      id: WalletAccountsStore.newId(),
      address: model.address,
      mnemonic: mnemonic,
      name: name ?? 'Wallet ${wallets.length + 1}',
      cardBackground: 'card_${(wallets.length % 10) + 1}.png',
      createdAt: DateTime.now(),
    );
    final updated = [...wallets, account];
    await _accounts.saveAll(updated);
    await _accounts.setActiveId(account.id);
    return account;
  }

  @override
  Future<void> removeWallet(String id) async {
    final wallets = await _accounts.loadAll();
    final remaining = wallets.where((w) => w.id != id).toList();
    await _accounts.saveAll(remaining);
    if (remaining.isEmpty) {
      await _accounts.clearActiveId();
    } else {
      final activeId = await _accounts.getActiveId();
      if (activeId == id) {
        await _accounts.setActiveId(remaining.first.id);
      }
    }
  }

  @override
  Future<void> renameWallet(String id, String name) async {
    final wallets = await _accounts.loadAll();
    final updated = wallets
        .map((w) => w.id == id ? w.copyWith(name: name) : w)
        .toList();
    await _accounts.saveAll(updated);
  }

  @override
  Future<void> setWalletCardBackground(String id, String cardBackground) async {
    final wallets = await _accounts.loadAll();
    final updated = wallets
        .map((w) =>
            w.id == id ? w.copyWith(cardBackground: cardBackground) : w)
        .toList();
    await _accounts.saveAll(updated);
  }
}
