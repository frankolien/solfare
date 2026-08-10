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
///
/// The rate limit lived inside PasscodeBloc, so it only applied to the unlock
/// screen. The recovery-phrase and private-key export dialogs read the stored
/// hash and called PasscodeCrypto.verify themselves — unlimited guesses
/// against a six-digit space, on the two screens that reveal the seed and the
/// private key. Both go through here now.
class PasscodeGate {
  const PasscodeGate._();

  static const int attemptsPerLockout = 3;

  static const _attemptsKey = 'passcode_failed_attempts';
  static const _lockoutUntilKey = 'passcode_lockout_until';

  /// How long the nth lockout lasts: 30s, 2m, 10m, then an hour thereafter.
  ///
  /// Escalating rather than flat. A fixed window is a fixed guess rate, and a
  /// fixed guess rate exhausts a six-digit passcode eventually — the old
  /// three-per-30-seconds worked out at roughly six a minute, forever.
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
      // durable and the key is reproducible from this point on. Dying
      // between the two steps leaves a v2 digest over plaintext mnemonics,
      // which is the state every install is in today — recoverable, because
      // the wrap below runs on every unlock rather than only on upgrade.
      if (PasscodeCrypto.needsUpgrade(stored)) {
        await storage.write(key: AppLock.passcodeKey, value: keys.stored);
      }

      WalletKey.hold(keys.wrapKey);
      try {
        final wrapped = await WalletAccountsStore().wrapPlaintextMnemonics(keys.wrapKey);
        if (wrapped > 0) debugLog('[Passcode] wrapped $wrapped mnemonic(s)');
      } catch (e) {
        // Not fatal to the unlock. The mnemonics stay plaintext and readable,
        // which is where every install is today, and the next unlock derives
        // the same key from the now-durable salt and tries again.
        debugLog('[Passcode] could not wrap mnemonics: $e');
      }

      await storage.delete(key: _attemptsKey);
      await storage.delete(key: _lockoutUntilKey);
      return const PasscodeAccepted();
    }

    // Not reset on lockout. Resetting is what made the limit flat.
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
