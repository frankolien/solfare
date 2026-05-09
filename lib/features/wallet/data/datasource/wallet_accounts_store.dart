import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solfare/core/security/secure_store.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';

// JSON-blob persistence for the wallet list + active-wallet pointer in
// secure storage. The pre-multi-wallet `wallet_mnemonic` / `wallet_address`
// keys are migrated by WalletLocalDataSourceImpl on first call.
class WalletAccountsStore {
  WalletAccountsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? SecureStore.instance;

  final FlutterSecureStorage _storage;

  static const _walletsKey = 'wallets_v1';
  static const _activeIdKey = 'active_wallet_id_v1';

  static final _rng = Random.secure();

  static String newId() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<List<WalletAccount>> loadAll() async {
    final raw = await _storage.read(key: _walletsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => WalletAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // Single write path so add/remove/rename all go through one atomic blob.
  Future<void> saveAll(List<WalletAccount> wallets) async {
    final payload = jsonEncode(wallets.map((w) => w.toJson()).toList());
    await _storage.write(key: _walletsKey, value: payload);
  }

  Future<String?> getActiveId() => _storage.read(key: _activeIdKey);

  Future<void> setActiveId(String id) =>
      _storage.write(key: _activeIdKey, value: id);

  Future<void> clearActiveId() => _storage.delete(key: _activeIdKey);

  Future<void> wipe() async {
    await _storage.delete(key: _walletsKey);
    await _storage.delete(key: _activeIdKey);
  }

  // Falls back to the first wallet (and persists the choice) if the active
  // pointer is missing or dangling — so the user never gets stuck on a
  // null-active state after a removal.
  Future<WalletAccount?> getActive() async {
    final wallets = await loadAll();
    if (wallets.isEmpty) return null;

    final id = await getActiveId();
    if (id != null) {
      for (final w in wallets) {
        if (w.id == id) return w;
      }
    }
    final fallback = wallets.first;
    await setActiveId(fallback.id);
    return fallback;
  }
}
