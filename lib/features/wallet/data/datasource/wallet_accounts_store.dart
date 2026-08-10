import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solfare/core/error/exception.dart';
import 'package:solfare/core/security/mnemonic_envelope.dart';
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
    } catch (e) {
      // Deliberately not an empty list. A blob that exists and will not
      // decode is the one case where guessing costs the user everything:
      // every mutator below reads, modifies and writes the whole list, so
      // "there are no wallets" would be persisted over a wallet that is
      // still sitting there intact, one decode bug away from readable.
      throw CorruptWalletStoreException('Stored wallets could not be read: $e');
    }
  }

  // Single write path so add/remove/rename all go through one atomic blob.
  //
  // Every caller reads through loadAll first, which throws rather than
  // returning empty on a blob it cannot decode — so this can never be
  // reached holding a list that lost entries to a parse failure.
  Future<void> saveAll(List<WalletAccount> wallets) async {
    final payload = jsonEncode(wallets.map((w) => w.toJson()).toList());
    await _storage.write(key: _walletsKey, value: payload);
  }

  /// Wraps any mnemonic still held in plaintext with [key].
  ///
  /// Runs on every unlock rather than only when the passcode digest was
  /// upgraded, which is what makes a half-finished migration recover itself:
  /// the digest is written first so the salt is durable, and if the process
  /// dies before this runs, the next unlock derives the same key and
  /// finishes the job. Gating on "was the digest old" would make that
  /// half-state permanent.
  ///
  /// Returns how many were wrapped, so a caller can log a migration without
  /// having to diff the store.
  Future<int> wrapPlaintextMnemonics(Uint8List key) async {
    final wallets = await loadAll();
    final wrapped = <WalletAccount>[];
    var changed = 0;

    for (final wallet in wallets) {
      if (MnemonicEnvelope.isWrapped(wallet.mnemonic)) {
        wrapped.add(wallet);
        continue;
      }
      wrapped.add(wallet.withMnemonic(MnemonicEnvelope.wrap(wallet.mnemonic, key)));
      changed++;
    }

    // One blob, one write. If it throws, nothing changed and the next
    // unlock tries again.
    if (changed > 0) await saveAll(wrapped);
    return changed;
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
