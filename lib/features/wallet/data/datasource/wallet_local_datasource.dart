import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfare/core/error/exception.dart';
import 'package:solfare/core/security/secure_store.dart';
import 'package:solfare/core/wallet/keyring.dart';
import 'package:solfare/features/wallet/data/datasource/wallet_accounts_store.dart';
import 'package:solfare/features/wallet/data/model/wallet_model.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';

/// Local wallet operations backed by [WalletAccountsStore]. The single-
/// wallet methods (saveWallet/getSavedAddress/etc.) all transparently
/// target the active account.
abstract class WalletLocalDataSource {
  Future<WalletModel> createWallet();
  Future<WalletModel> deriveWallet(String mnemonic);
  Future<void> saveWallet(WalletModel wallet);
  Future<bool> hasWallet();
  Future<String?> getSavedAddress();
  Future<void> clearWallet();
  Future<String?> getStoredMnemonic();

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

  // Pre-multi-wallet keys. Read once by the migration, then deleted.
  static const _legacyMnemonicKey = 'wallet_mnemonic';
  static const _legacyAddressKey = 'wallet_address';
  static const _migrationDoneKey = 'multi_wallet_migrated_v1';

  WalletLocalDataSourceImpl({
    FlutterSecureStorage? secureStorage,
    WalletAccountsStore? accountsStore,
  })  : _secureStorage = secureStorage ?? SecureStore.instance,
        _accounts = accountsStore ?? WalletAccountsStore(storage: secureStorage);

  // Lazy one-shot: runs on first call after upgrade. If a pre-multi-wallet
  // entry exists, fold it into the new accounts store and delete the
  // legacy keys so the mnemonic doesn't sit duplicated in storage.
  Future<void> _runMigrationIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_migrationDoneKey) == true) return;

      final existing = await _accounts.loadAll();
      if (existing.isNotEmpty) {
        await prefs.setBool(_migrationDoneKey, true);
        return;
      }

      final legacyMnemonic = await _secureStorage.read(key: _legacyMnemonicKey);
      final legacyAddress = await _secureStorage.read(key: _legacyAddressKey);
      if (legacyMnemonic == null || legacyMnemonic.isEmpty) {
        await prefs.setBool(_migrationDoneKey, true);
        return;
      }

      // Name + card came from SharedPreferences, not secure storage.
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

      await _secureStorage.delete(key: _legacyMnemonicKey);
      await _secureStorage.delete(key: _legacyAddressKey);
      await prefs.setBool(_migrationDoneKey, true);
    } catch (_) {
      // Don't throw — leave legacy keys in place so the next launch retries.
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
    final derived = await Keyring.publicKeyFor(mnemonic);
    return WalletModel.fromKeyData(
      address: derived.address,
      publicKey: derived.publicKey,
      mnemonic: mnemonic,
    );
  }

  @override
  Future<void> saveWallet(WalletModel wallet) async {
    await _runMigrationIfNeeded();
    await addWallet(wallet.mnemonic);
  }

  @override
  Future<bool> hasWallet() async {
    try {
      await _runMigrationIfNeeded();
      final wallets = await _accounts.loadAll();
      if (wallets.isEmpty) return false;

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
      // Clear legacy keys too in case wipe is called pre-migration.
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

    final existing = wallets
        .where((w) => w.address == model.address)
        .cast<WalletAccount?>()
        .firstWhere((_) => true, orElse: () => null);
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
