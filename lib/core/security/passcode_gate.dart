import 'dart:typed_data';

import 'package:solfare/core/security/app_lock.dart';
import 'package:solfare/core/security/passcode_crypto.dart';
import 'package:solfare/core/security/secure_store.dart';
import 'package:solfare/core/security/wallet_key.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/wallet/data/datasource/wallet_accounts_store.dart';

/// The result of one passcode attempt.
sealed class PasscodeAttempt {
  const PasscodeAttempt();
}

class PasscodeAccepted extends PasscodeAttempt {
  const PasscodeAccepted();
}

class PasscodeWrong extends PasscodeAttempt {
  /// How many tries remain before the next lockout.
  final int remaining;

  const PasscodeWrong(this.remaining);
}

class PasscodeLocked extends PasscodeAttempt {
  final Duration remaining;

  const PasscodeLocked(this.remaining);
}

class PasscodeUnset extends PasscodeAttempt {
  const PasscodeUnset();
}

/// The one place a passcode is checked.
class PasscodeGate {
  const PasscodeGate._();

  static const int attemptsPerLockout = 3;

  static const _attemptsKey = 'passcode_failed_attempts';
  static const _lockoutUntilKey = 'passcode_lockout_until';

  /// How long the nth lockout lasts: 30s, 2m, 10m, then an hour thereafter.
  static Duration lockoutFor(int lockoutNumber) => switch (lockoutNumber) {
        <= 1 => const Duration(seconds: 30),
        2 => const Duration(minutes: 2),
        3 => const Duration(minutes: 10),
        _ => const Duration(hours: 1),
      };

  static Future<PasscodeAttempt> verify(String passcode) async {
    final storage = SecureStore.instance;

    final lockedUntil =
        int.tryParse(await storage.read(key: _lockoutUntilKey) ?? '') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (lockedUntil > nowMs) {
      return PasscodeLocked(Duration(milliseconds: lockedUntil - nowMs));
    }

    final stored = await storage.read(key: AppLock.passcodeKey);
    if (stored == null) return const PasscodeUnset();

    final keys = await PasscodeCrypto.verifyAndDerive(passcode, stored);
    if (keys != null) {
      // The digest is written before anything is wrapped, so the salt is
      // durable and the key is reproducible from this point on.
      if (PasscodeCrypto.needsUpgrade(stored)) {
        await storage.write(key: AppLock.passcodeKey, value: keys.stored);
      }

      await holdAndMigrate(keys.wrapKey);

      await storage.delete(key: _attemptsKey);
      await storage.delete(key: _lockoutUntilKey);
      return const PasscodeAccepted();
    }

    // Not reset on lockout.
    final attempts =
        (int.tryParse(await storage.read(key: _attemptsKey) ?? '') ?? 0) + 1;
    await storage.write(key: _attemptsKey, value: '$attempts');

    if (attempts % attemptsPerLockout == 0) {
      final lockout = lockoutFor(attempts ~/ attemptsPerLockout);
      await storage.write(
        key: _lockoutUntilKey,
        value: '${nowMs + lockout.inMilliseconds}',
      );
      return PasscodeLocked(lockout);
    }

    return PasscodeWrong(attemptsPerLockout - (attempts % attemptsPerLockout));
  }

  /// Take up [wrapKey] for the unlocked session and finish any migration.
  ///
  /// Shared by the passcode and the biometric door, so both end in the same
  /// state — a biometric unlock that skipped the wrap would leave a mnemonic
  /// in plaintext for as long as the user never typed their passcode again.
  static Future<void> holdAndMigrate(Uint8List wrapKey) async {
    WalletKey.hold(wrapKey);
    try {
      final wrapped = await WalletAccountsStore().wrapPlaintextMnemonics(wrapKey);
      if (wrapped > 0) debugLog('[Passcode] wrapped $wrapped mnemonic(s)');
    } catch (e) {
      // Not fatal to the unlock.
      debugLog('[Passcode] could not wrap mnemonics: $e');
    }
  }

  /// Human wording for a lockout, so every caller says the same thing.
  static String describe(Duration lockout) {
    if (lockout.inMinutes < 1) {
      return 'Too many attempts. Try again in ${lockout.inSeconds}s.';
    }
    if (lockout.inHours < 1) {
      return 'Too many attempts. Try again in ${lockout.inMinutes}m.';
    }
    return 'Too many attempts. Try again in ${lockout.inHours}h.';
  }
}
