import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Single, explicitly-configured FlutterSecureStorage instance shared by
/// every callsite that needs to read or write key material.
///
/// iOS: keychain items become unavailable until the device is unlocked the
/// first time after boot, and never sync to iCloud. Android uses the
/// plugin's default custom-cipher backing (Jetpack Security's
/// EncryptedSharedPreferences was deprecated upstream in v10).
///
/// Every option here has to be stated. The defaults are not neutral, and at
/// least one of them is documented as the opposite of what it does.
class SecureStore {
  SecureStore._();

  static const _ios = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  // resetOnError defaults to TRUE in flutter_secure_storage 10, whatever its
  // own doc comment claims, and the native side honours it by calling
  // deleteAll() on any storage error. A KeyStore key invalidated by an OS
  // upgrade, an OEM lock-screen change or a backup restore would therefore
  // delete the user's seed phrase — which this app has not shown them since
  // onboarding. An unreadable store is a problem to report, never one to
  // resolve by destroying the contents.
  static const _android = AndroidOptions(resetOnError: false);

  static const FlutterSecureStorage instance = FlutterSecureStorage(
    iOptions: _ios,
    aOptions: _android,
  );
}
