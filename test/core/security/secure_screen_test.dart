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
}
