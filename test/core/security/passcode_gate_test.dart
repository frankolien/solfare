import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/security/app_lock.dart';
import 'package:solfare/core/security/passcode_crypto.dart';
import 'package:solfare/core/security/passcode_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> backing;
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() async {
    backing = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
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
        case 'deleteAll':
          backing.clear();
          return null;
      }
      return null;
    });
    backing[AppLock.passcodeKey] = await PasscodeCrypto.hash('123456');
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('the right passcode is accepted', () async {
    expect(await PasscodeGate.verify('123456'), isA<PasscodeAccepted>());
  });

  test('a wrong one is refused and counts down to the lockout', () async {
    final first = await PasscodeGate.verify('000000');
    expect(first, isA<PasscodeWrong>());
    expect((first as PasscodeWrong).remaining, PasscodeGate.attemptsPerLockout - 1);
  });

  test('the lockout arrives on the third wrong attempt', () async {
    await PasscodeGate.verify('000000');
    await PasscodeGate.verify('000000');
    expect(await PasscodeGate.verify('000000'), isA<PasscodeLocked>());
  });

  test('a locked gate refuses even the right passcode', () async {
    for (var i = 0; i < PasscodeGate.attemptsPerLockout; i++) {
      await PasscodeGate.verify('000000');
    }
    expect(await PasscodeGate.verify('123456'), isA<PasscodeLocked>());
  });

  test('each lockout costs more than the last', () async {
    // The old code reset the counter when it locked, so the limit was a flat
    // three-guesses-per-30-seconds forever — about six a minute against a
    // six-digit space.
    expect(PasscodeGate.lockoutFor(1), lessThan(PasscodeGate.lockoutFor(2)));
    expect(PasscodeGate.lockoutFor(2), lessThan(PasscodeGate.lockoutFor(3)));
    expect(PasscodeGate.lockoutFor(4), greaterThanOrEqualTo(PasscodeGate.lockoutFor(3)));
  });

  test('the counter survives the lockout rather than resetting', () async {
    for (var i = 0; i < PasscodeGate.attemptsPerLockout; i++) {
      await PasscodeGate.verify('000000');
    }
    expect(backing['passcode_failed_attempts'], '3',
        reason: 'resetting here is what made the rate limit flat');
  });

  test('a correct entry clears the counter and the lockout', () async {
    await PasscodeGate.verify('000000');
    await PasscodeGate.verify('123456');
    expect(backing.containsKey('passcode_failed_attempts'), isFalse);
    expect(backing.containsKey('passcode_lockout_until'), isFalse);
  });

  test('no passcode set is its own answer, not a wrong guess', () async {
    backing.remove(AppLock.passcodeKey);
    expect(await PasscodeGate.verify('123456'), isA<PasscodeUnset>());
  });
}
