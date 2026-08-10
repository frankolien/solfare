import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/security/app_lock.dart';

void main() {
  final lock = AppLock.instance;

  setUp(lock.resetForTest);

  test('a wallet with no passcode has nothing to lock', () {
    expect(lock.isLocked, isFalse);
  });

  test('a passcode that exists and has not been entered holds the door', () {
    lock.adopt();
    lock.lock();
    expect(lock.isLocked, isTrue);
  });

  test('setting a passcode does not immediately lock the user out of it', () {
    // They are holding the phone and have just typed it twice.
    lock.adopt();
    expect(lock.isLocked, isFalse);
  });

  test('entering the passcode opens the door', () {
    lock.adopt();
    lock.lock();
    lock.unlock();
    expect(lock.isLocked, isFalse);
  });

  test('forgetting the passcode leaves nothing to unlock', () {
    // A wallet reset takes the passcode with it. Without this the router
    // would hold the user on an unlock screen for a wallet that is gone.
    lock.adopt();
    lock.lock();
    lock.forget();
    expect(lock.isLocked, isFalse);
    expect(lock.hasPasscode, isFalse);
  });

  group('notifications', () {
    test('locking tells the router, so the redirect re-runs', () {
      var notified = 0;
      void listener() => notified++;
      lock.adopt();
      lock.addListener(listener);
      addTearDown(() => lock.removeListener(listener));

      lock.lock();
      expect(notified, 1);
    });

    test('a redundant lock is not an event', () {
      // GoRouter rebuilds on every notification; repeating one that changes
      // nothing costs a redirect pass per background/foreground cycle.
      lock.adopt();
      lock.lock();
      var notified = 0;
      void listener() => notified++;
      lock.addListener(listener);
      addTearDown(() => lock.removeListener(listener));

      lock.lock();
      expect(notified, 0);
    });
  });

  group('background', () {
    test('a short trip to another app does not re-lock', () {
      lock.adopt();
      final left = DateTime(2026, 8, 10, 12);
      lock.didLeave(at: left);
      lock.didReturn(at: left.add(const Duration(seconds: 5)));
      expect(lock.isLocked, isFalse,
          reason: 'copying an address elsewhere must not cost a passcode');
    });

    test('a long absence re-locks', () {
      lock.adopt();
      final left = DateTime(2026, 8, 10, 12);
      lock.didLeave(at: left);
      lock.didReturn(at: left.add(AppLock.lockAfter));
      expect(lock.isLocked, isTrue);
    });

    test('the phone left overnight comes back locked', () {
      lock.adopt();
      final left = DateTime(2026, 8, 10, 9);
      lock.didLeave(at: left);
      lock.didReturn(at: DateTime(2026, 8, 10, 17));
      expect(lock.isLocked, isTrue);
    });

    test('a clock that moved backwards re-locks rather than staying open', () {
      // Anything not clearly inside the window is treated as outside it.
      lock.adopt();
      final left = DateTime(2026, 8, 10, 12);
      lock.didLeave(at: left);
      lock.didReturn(at: left.subtract(const Duration(hours: 3)));
      expect(lock.isLocked, isTrue);
    });

    test('returning without having left changes nothing', () {
      // onRestart can arrive without a paired onPause on some platforms.
      lock.adopt();
      lock.didReturn(at: DateTime(2026, 8, 10, 12));
      expect(lock.isLocked, isFalse);
    });

    test('backgrounding while already locked stays locked', () {
      lock.adopt();
      lock.lock();
      final left = DateTime(2026, 8, 10, 12);
      lock.didLeave(at: left);
      lock.didReturn(at: left.add(const Duration(seconds: 1)));
      expect(lock.isLocked, isTrue);
    });
  });
}
