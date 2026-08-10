import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/security/secure_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('solfare/secure_screen');
  late List<String> recordedCalls;

  void install(Future<dynamic> Function(MethodCall)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  setUp(() {
    recordedCalls = [];
    SecureScreen.resetForTest();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    install((call) async {
      recordedCalls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    install(null);
  });

  group('SecureScreen iOS channel', () {
    test('enable() invokes the native "enable" method', () async {
      await SecureScreen.enable();
      expect(recordedCalls, equals(['enable']));
    });

    test('disable() invokes the native "disable" method', () async {
      // Enabled first: disable() is refcounted now, and calling it with
      // nothing protected is a no-op rather than a native call. That is the
      // whole point — see the nesting group below.
      await SecureScreen.enable();
      recordedCalls.clear();
      await SecureScreen.disable();
      expect(recordedCalls, equals(['disable']));
    });

    test('repeated enable/disable produces the expected call sequence', () async {
      await SecureScreen.enable();
      await SecureScreen.disable();
      await SecureScreen.enable();
      expect(recordedCalls, equals(['enable', 'disable', 'enable']));
    });

    test('enable() silently no-ops when the native handler is missing', () async {
      install(null);
      await expectLater(SecureScreen.enable(), completes);
    });
  });

  group('nesting', () {
    test('an inner screen closing does not unprotect the outer one', () async {
      // The bug this refcount exists for: the confirm step is pushed on top
      // of the screen still displaying the twelve words, so backing out of
      // it called disable() and left the seed behind it screenshot-able.
      await SecureScreen.enable(); // recovery phrase on screen
      await SecureScreen.enable(); // confirm pushed over it
      await SecureScreen.disable(); // confirm popped

      expect(SecureScreen.isEnabled, isTrue);
      expect(recordedCalls, equals(['enable']),
          reason: 'the native side is only told when the state actually changes');
    });

    test('the last screen out turns it off', () async {
      await SecureScreen.enable();
      await SecureScreen.enable();
      await SecureScreen.disable();
      await SecureScreen.disable();

      expect(SecureScreen.isEnabled, isFalse);
      expect(recordedCalls, equals(['enable', 'disable']));
    });

    test('an unbalanced disable cannot drive the count negative', () async {
      await SecureScreen.disable();
      await SecureScreen.enable();
      expect(SecureScreen.isEnabled, isTrue);
      expect(recordedCalls, equals(['enable']));
    });
  });
}
