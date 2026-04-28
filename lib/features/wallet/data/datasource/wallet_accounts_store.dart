import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';

/// Persists a list of wallet accounts + an active-wallet pointer in secure
/// storage. FlutterSecureStorage backs onto iOS Keychain / Android Keystore
/// so the blob is encrypted at rest by the OS.
///
/// Storage keys:
///   `wallets_v1`            → JSON array of accounts
///   `active_wallet_id_v1`   → id of the currently selected wallet
///
/// The legacy `wallet_mnemonic` / `wallet_address` keys are read once by the
/// migration in [WalletRepositoryImpl] and then removed.
class WalletAccountsStore {
  WalletAccountsStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _walletsKey = 'wallets_v1';
  static const _activeIdKey = 'active_wallet_id_v1';

  static final _rng = Random.secure();

  /// Create a random 16-byte hex id for a new wallet.
  static String newId() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Load all accounts. Empty list if none stored.
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

  /// Replace the entire wallet list. Used by add/remove/update flows so
  /// writes go through one atomic path.
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

  /// Resolves the currently-active account. Returns null if nothing is stored
  /// or the pointer is dangling. When the pointer is missing but wallets
  /// exist, defaults to the first one (and persists that choice).
  Future<WalletAccount?> getActive() async {
    final wallets = await loadAll();
    if (wallets.isEmpty) return null;

    final id = await getActiveId();
    if (id != null) {
      for (final w in wallets) {
        if (w.id == id) return w;
      }
    }
    // Fallback: first wallet in list.
    final fallback = wallets.first;
    await setActiveId(fallback.id);
    return fallback;
  }
}
