import 'package:solfare/core/security/app_lock.dart';
import 'package:solfare/core/security/biometric_lock.dart';
import 'package:solfare/core/security/mnemonic_envelope.dart';
import 'package:solfare/core/security/passcode_crypto.dart';
import 'package:solfare/core/security/passcode_gate.dart';
import 'package:solfare/core/security/secure_store.dart';
import 'package:solfare/core/security/wallet_key.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/wallet/data/datasource/wallet_accounts_store.dart';

/// Replacing the passcode, and everything sealed with the key it derived.
///
/// See docs/design/round-two.md.
class PasscodeChange {
  const PasscodeChange._();

  /// Swap [current] for [next].
  ///
  /// The stored mnemonics are sealed with the key the *old* passcode derived.
  /// Writing a new digest without re-sealing them strands every wallet behind
  /// a key nothing can derive again, so the order is: open everything while
  /// the old key is still held, write the new digest, then seal with the new
  /// key. A crash between the last two leaves plaintext mnemonics under a
  /// valid digest, which the unlock path already repairs.
  static Future<PasscodeChangeResult> apply({
    required String current,
    required String next,
  }) async {
    final attempt = await PasscodeGate.verify(current);
    switch (attempt) {
      case PasscodeWrong(:final remaining):
        return PasscodeChangeResult.wrong(remaining);
      case PasscodeLocked(:final remaining):
        return PasscodeChangeResult.locked(remaining);
      case PasscodeUnset():
        return const PasscodeChangeResult.failed('No passcode is set.');
      case PasscodeAccepted():
        break;
    }

    final oldKey = WalletKey.value;
    if (oldKey == null) {
      return const PasscodeChangeResult.failed(
        'Could not read your wallet. Try again.',
      );
    }

    try {
      final store = WalletAccountsStore();
      final wallets = await store.loadAll();

      // Opened before anything is overwritten. If a single one cannot be read,
      // stop — a partial rewrite is how a wallet is lost.
      final opened = <String, String>{
        for (final w in wallets) w.id: MnemonicEnvelope.unwrap(w.mnemonic, oldKey),
      };

      final made = await PasscodeCrypto.create(next);
      await SecureStore.instance
          .write(key: AppLock.passcodeKey, value: made.stored);

      await store.saveAll([
        for (final w in wallets)
          w.withMnemonic(MnemonicEnvelope.wrap(opened[w.id]!, made.keys.wrapKey)),
      ]);

      WalletKey.hold(made.keys.wrapKey);
      await BiometricLock.rekey(made.keys.wrapKey);
      return const PasscodeChangeResult.changed();
    } catch (e) {
      debugLog('[Passcode] change failed: $e');
      return const PasscodeChangeResult.failed(
        'Could not change your passcode. Nothing was changed.',
      );
    }
  }
}

/// What one change attempt did.
sealed class PasscodeChangeResult {
  const PasscodeChangeResult();

  const factory PasscodeChangeResult.changed() = PasscodeChanged;
  const factory PasscodeChangeResult.wrong(int remaining) = PasscodeChangeWrong;
  const factory PasscodeChangeResult.locked(Duration remaining) =
      PasscodeChangeLocked;
  const factory PasscodeChangeResult.failed(String message) =
      PasscodeChangeFailed;
}

class PasscodeChanged extends PasscodeChangeResult {
  const PasscodeChanged();
}

class PasscodeChangeWrong extends PasscodeChangeResult {
  final int remaining;

  const PasscodeChangeWrong(this.remaining);
}

class PasscodeChangeLocked extends PasscodeChangeResult {
  final Duration remaining;

  const PasscodeChangeLocked(this.remaining);
}

class PasscodeChangeFailed extends PasscodeChangeResult {
  final String message;

  const PasscodeChangeFailed(this.message);
}
