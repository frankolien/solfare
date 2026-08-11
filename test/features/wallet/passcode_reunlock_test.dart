import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/security/app_lock.dart';
import 'package:solfare/core/security/biometric_lock.dart';
import 'package:solfare/core/security/passcode_crypto.dart';
import 'package:solfare/core/security/wallet_key.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const auth = MethodChannel('plugins.flutter.io/local_auth');

  late Map<String, String> backing;
  late PasscodeBloc bloc;

  setUp(() async {
    backing = {};
    WalletKey.resetForTest();
    AppLock.instance.resetForTest();

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
        case 'readAll':
          return Map<String, String>.from(backing);
      }
      return null;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(auth, (call) async {
      switch (call.method) {
        case 'isDeviceSupported':
          return true;
        case 'getAvailableBiometrics':
          return ['face'];
      }
      return null;
    });

    // An install with a passcode and Face ID already turned on.
    final made = await PasscodeCrypto.create('123456');
    backing[AppLock.passcodeKey] = made.stored;
    await BiometricLock.enable(made.keys.wrapKey);
    // isLocked is `hasPasscode && !unlocked`, so the lock has to know a
    // passcode exists before it can hold anything shut.
    await AppLock.instance.load();

    bloc = PasscodeBloc();
  });

  tearDown(() async {
    await bloc.close();
    WalletKey.resetForTest();
    AppLock.instance.resetForTest();
    for (final c in [storage, auth]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(c, null);
    }
  });

  test('a second Face ID unlock still reaches the screen', () async {
    // The bloc is app-level, so it survives the lock. After one unlock its
    // state is PasscodeVerified, and an identical Equatable state is dropped —
    // so the screen's listener never fired and the app sat on the keypad
    // having just accepted a face.
    bloc.add(const BiometricUnlockRequested());
    expect(await bloc.stream.firstWhere((s) => s is PasscodeVerified),
        isA<PasscodeVerified>());

    // Backgrounded long enough to re-lock.
    AppLock.instance.lock();
    expect(AppLock.instance.isLocked, isTrue);

    final seen = <PasscodeState>[];
    final sub = bloc.stream.listen(seen.add);

    bloc.add(const BiometricUnlockRequested());
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();

    expect(seen.whereType<PasscodeVerified>(), isNotEmpty,
        reason: 'without an emission the screen cannot navigate');
    expect(AppLock.instance.isLocked, isFalse);
  });

  test('the key is held again after the second unlock', () async {
    bloc.add(const BiometricUnlockRequested());
    await bloc.stream.firstWhere((s) => s is PasscodeVerified);

    AppLock.instance.lock();
    expect(WalletKey.isHeld, isFalse, reason: 'locking drops it');

    bloc.add(const BiometricUnlockRequested());
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(WalletKey.isHeld, isTrue);
  });
}
