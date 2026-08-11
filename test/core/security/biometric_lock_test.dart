import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/security/biometric_lock.dart';
import 'package:solfare/core/security/mnemonic_envelope.dart';
import 'package:solfare/core/security/passcode_crypto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const auth = MethodChannel('plugins.flutter.io/local_auth');

  late Map<String, String> backing;
  late List<String> enrolled;
  late bool deviceSupported;

  void mockStorage() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'read':
          return backing[args['key']];
        case 'write':
          backing[args['key']] = args['value'] as String;
          return null;
        case 'delete':
          backing.remove(args['key']);
          return null;
      }
      return null;
    });
  }

  void mockAuth() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(auth, (call) async {
      switch (call.method) {
        case 'isDeviceSupported':
          return deviceSupported;
        case 'getAvailableBiometrics':
          return enrolled;
      }
      return null;
    });
  }

  setUp(() {
    backing = {};
    enrolled = ['face'];
    deviceSupported = true;
    mockStorage();
    mockAuth();
  });

  tearDown(() {
    for (final c in [storage, auth]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(c, null);
    }
  });

  test('a device with no enrolled biometrics stores nothing', () async {
    enrolled = [];
    final keys = (await PasscodeCrypto.create('123456')).keys;

    expect(await BiometricLock.enable(keys.wrapKey), isFalse);
    expect(backing, isEmpty,
        reason: 'a stored key nothing can retrieve is worse than no key');
    expect(await BiometricLock.isEnabled(), isFalse);
  });

  test('an unsupported device is not offered the toggle', () async {
    deviceSupported = false;
    expect(await BiometricLock.isAvailable(), isFalse);
  });

  test('the button is named after what the device actually has', () async {
    expect(await BiometricLock.label(), 'Face ID');
    enrolled = ['fingerprint'];
    expect(await BiometricLock.label(), 'Touch ID');
    enrolled = [];
    expect(await BiometricLock.label(), 'Biometrics');
  });

  test('the stored key is the same one the passcode derives', () async {
    // The whole design turns on this: biometrics is a second door to one key,
    // not a second key. If these ever diverge the mnemonic is unreadable.
    final made = await PasscodeCrypto.create('123456');
    await BiometricLock.enable(made.keys.wrapKey);

    expect(await BiometricLock.unlock(), made.keys.wrapKey);
  });

  test('a mnemonic wrapped by the passcode opens with the biometric key',
      () async {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon about';
    final made = await PasscodeCrypto.create('123456');
    final sealed = MnemonicEnvelope.wrap(mnemonic, made.keys.wrapKey);

    await BiometricLock.enable(made.keys.wrapKey);
    final viaBiometrics = await BiometricLock.unlock();

    expect(MnemonicEnvelope.unwrap(sealed, viaBiometrics), mnemonic);
  });

  test('unlock returns null when it was never enabled', () async {
    expect(await BiometricLock.unlock(), isNull);
  });

  test('a keychain that refuses the read yields nothing', () async {
    final made = await PasscodeCrypto.create('123456');
    await BiometricLock.enable(made.keys.wrapKey);

    // What an invalidated item looks like: the flag is still readable, the
    // protected item is not.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (call) async {
      final args = (call.arguments as Map?) ?? const {};
      if (call.method == 'read' && args['key'] == 'wallet_biometric_key') {
        throw PlatformException(code: 'BiometryLockout');
      }
      if (call.method == 'read') return backing[args['key']];
      if (call.method == 'delete') backing.remove(args['key']);
      return null;
    });

    expect(await BiometricLock.unlock(), isNull);
  });

  test('a missing item disables itself rather than prompting again', () async {
    final made = await PasscodeCrypto.create('123456');
    await BiometricLock.enable(made.keys.wrapKey);
    backing.remove('wallet_biometric_key');

    expect(await BiometricLock.unlock(), isNull);
    expect(await BiometricLock.isEnabled(), isFalse);
  });

  test('disable clears both the key and the flag', () async {
    final made = await PasscodeCrypto.create('123456');
    await BiometricLock.enable(made.keys.wrapKey);
    expect(backing.keys, hasLength(2));

    await BiometricLock.disable();
    expect(backing, isEmpty);
  });

  test('rekey replaces the stored key after a passcode change', () async {
    final first = await PasscodeCrypto.create('111111');
    await BiometricLock.enable(first.keys.wrapKey);

    final second = await PasscodeCrypto.create('222222');
    await BiometricLock.rekey(second.keys.wrapKey);

    expect(await BiometricLock.unlock(), second.keys.wrapKey);
    expect(base64Decode(backing['wallet_biometric_key']!),
        isNot(first.keys.wrapKey));
  });

  test('rekey on a wallet that never enabled it stores nothing', () async {
    final made = await PasscodeCrypto.create('123456');
    await BiometricLock.rekey(made.keys.wrapKey);

    expect(backing, isEmpty);
  });
}
