import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:solfare/core/security/secure_store.dart';
import 'package:solfare/core/util/app_log.dart';

/// Face ID or Touch ID as a second door to the key the passcode derives.
///
/// See docs/design/biometric-unlock.md.
class BiometricLock {
  const BiometricLock._();

  static const _keyItem = 'wallet_biometric_key';
  static const _flagItem = 'wallet_biometric_enabled';

  static final _auth = LocalAuthentication();

  // The OS releases this item only after it authenticates the person holding
  // the phone, so the wrapKey is never readable from a storage dump.
  // biometryCurrentSet invalidates it the moment a new face or finger is
  // enrolled; the passcode still works, so the cost of that is one prompt.
  // `passcode` is WhenPasscodeSetThisDeviceOnly: no device passcode, no item,
  // and it never syncs anywhere.
  static const _protected = IOSOptions(
    accessibility: KeychainAccessibility.passcode,
    accessControlFlags: [AccessControlFlag.biometryCurrentSet],
  );

  /// Whether this device has biometrics that are set up and usable.
  static Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (e) {
      debugLog('[Biometric] capability check failed: $e');
      return false;
    }
  }

  /// What to call it on a button.
  static Future<String> label() async {
    try {
      final kinds = await _auth.getAvailableBiometrics();
      if (kinds.contains(BiometricType.face)) return 'Face ID';
      if (kinds.contains(BiometricType.fingerprint) ||
          kinds.contains(BiometricType.strong)) {
        return 'Touch ID';
      }
    } catch (_) {
      // Fall through to the generic wording.
    }
    return 'Biometrics';
  }

  /// Whether the user has turned it on.
  ///
  /// A plain item, so the unlock screen can decide whether to offer the button
  /// without raising a prompt to find out.
  static Future<bool> isEnabled() async {
    try {
      return await SecureStore.instance.read(key: _flagItem) == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Stores [wrapKey] behind biometry. Caller must hold a verified key.
  ///
  /// Writes, then reads it straight back. Writing under an access control needs
  /// no authentication — only reading does — so without the read the user taps
  /// the toggle and sees nothing at all, and we would be claiming a feature
  /// works without having checked. The read raises the prompt and proves the
  /// round trip, here rather than at the next unlock.
  static Future<bool> enable(Uint8List wrapKey) async {
    if (!await isAvailable()) return false;
    try {
      await SecureStore.instance.write(
        key: _keyItem,
        value: base64Encode(wrapKey),
        iOptions: _protected,
      );

      final readBack = await SecureStore.instance.read(
        key: _keyItem,
        iOptions: _protected,
      );
      if (readBack == null || !_sameBytes(base64Decode(readBack), wrapKey)) {
        await disable();
        return false;
      }

      await SecureStore.instance.write(key: _flagItem, value: 'true');
      return true;
    } catch (e) {
      // Includes the user dismissing the prompt, which is a refusal to turn it
      // on rather than an error to report.
      debugLog('[Biometric] could not store the key: $e');
      await disable();
      return false;
    }
  }

  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Prompts, and returns the wrapKey on success.
  ///
  /// Null covers cancel, failure, and an item the OS invalidated because the
  /// enrolled biometrics changed — none of which the caller treats differently:
  /// the passcode keypad is already on screen.
  static Future<Uint8List?> unlock() async {
    if (!await isEnabled()) return null;
    try {
      final stored = await SecureStore.instance.read(
        key: _keyItem,
        iOptions: _protected,
      );
      if (stored == null) {
        await disable();
        return null;
      }
      return base64Decode(stored);
    } catch (e) {
      debugLog('[Biometric] unlock declined: $e');
      return null;
    }
  }

  /// Forgets the stored key. Safe to call when nothing is stored.
  static Future<void> disable() async {
    try {
      await SecureStore.instance.delete(key: _keyItem, iOptions: _protected);
      await SecureStore.instance.delete(key: _flagItem);
    } catch (e) {
      debugLog('[Biometric] could not clear: $e');
    }
  }

  /// The passcode changed, so [wrapKey] did too.
  ///
  /// Rewriting rather than leaving it is the whole point: a stale key decrypts
  /// nothing, and that surfaces to the user as an unreadable recovery phrase.
  static Future<void> rekey(Uint8List wrapKey) async {
    if (!await isEnabled()) return;
    await disable();
    await enable(wrapKey);
  }
}
