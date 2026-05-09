import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Single, explicitly-configured FlutterSecureStorage instance shared by
/// every callsite that needs to read or write key material.
///
/// iOS: keychain items become unavailable until the device is unlocked the
/// first time after boot, and never sync to iCloud. Android uses the
/// plugin's default custom-cipher backing (Jetpack Security's
/// EncryptedSharedPreferences was deprecated upstream in v10).
class SecureStore {
  SecureStore._();

  static const _ios = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  static const FlutterSecureStorage instance = FlutterSecureStorage(
    iOptions: _ios,
  );
}
