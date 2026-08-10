import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Single, explicitly-configured FlutterSecureStorage instance shared by every
/// callsite that needs to read or write key material.
class SecureStore {
  SecureStore._();

  static const _ios = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  // resetOnError defaults to TRUE in flutter_secure_storage 10, whatever its
  // own doc comment claims, and the native side honours it by calling
  // deleteAll() on any storage error.
  static const _android = AndroidOptions(resetOnError: false);

  static const FlutterSecureStorage instance = FlutterSecureStorage(
    iOptions: _ios,
    aOptions: _android,
  );
}
