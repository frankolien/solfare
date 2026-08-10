import 'package:flutter/foundation.dart';
import 'package:solfare/core/security/secure_store.dart';

/// Whether the app is currently allowed to be used.
///
/// The passcode used to be a single navigation decision taken once on the
/// splash screen. Anything that navigated by another route — a `solfare://`
/// deeplink, the router's own exception handler — landed on the homepage
/// with full spend authority, and nothing re-checked afterwards. This holds
/// the fact instead, so the router can refuse rather than the splash screen
/// having to be the only door.
///
/// A [ChangeNotifier] because GoRouter takes one directly as its
/// `refreshListenable`: locking has to re-run the redirect, not just be true
/// the next time somebody happens to navigate.
class AppLock extends ChangeNotifier {
  AppLock._();

  static final AppLock instance = AppLock._();

  /// The key the passcode hash is stored under. Owned here because whether a
  /// passcode exists is what decides if there is anything to lock.
  static const passcodeKey = 'wallet_passcode';

  /// How long the app may sit in the background before it re-locks.
  ///
  /// Zero would re-prompt every time the user checked an address in another
  /// app, which trains them to type the passcode without reading the screen.
  /// A minute is long enough to survive a copy-paste round trip and short
  /// enough that a phone handed to somebody else arrives locked.
  static const lockAfter = Duration(seconds: 60);

  bool _hasPasscode = false;
  bool _unlocked = false;
  DateTime? _leftAt;

  /// True when a passcode exists and it has not been entered this session.
  /// Read synchronously by the router's redirect, so it can never be a future.
  bool get isLocked => _hasPasscode && !_unlocked;

  /// Whether the user has set a passcode at all. A wallet created before the
  /// passcode step is finished has nothing to unlock.
  bool get hasPasscode => _hasPasscode;

  /// Reads the stored passcode once, before the first frame. Called from
  /// `main` so the first redirect already knows whether to hold the door.
  Future<void> load() async {
    try {
      _hasPasscode = await SecureStore.instance.read(key: passcodeKey) != null;
    } catch (_) {
      // A storage read that fails is not evidence there is no passcode. Assume
      // there is one: the cost of a wrong guess in this direction is a prompt
      // the user can satisfy, and in the other direction it is an open wallet.
      _hasPasscode = true;
    }
    notifyListeners();
  }

  /// The passcode was entered correctly.
  void unlock() {
    _leftAt = null;
    if (_unlocked) return;
    _unlocked = true;
    notifyListeners();
  }

  /// A passcode was just set, which both creates the lock and satisfies it.
  void adopt() {
    _hasPasscode = true;
    _unlocked = true;
    _leftAt = null;
    notifyListeners();
  }

  /// The passcode was removed — a wallet reset, or a logout.
  void forget() {
    _hasPasscode = false;
    _unlocked = false;
    _leftAt = null;
    notifyListeners();
  }

  /// Require the passcode again on the next navigation.
  void lock() {
    _leftAt = null;
    if (!_unlocked) return;
    _unlocked = false;
    notifyListeners();
  }

  /// The app went to the background. Only the time is recorded — locking
  /// here would tear down whatever the user was doing while they are not
  /// looking, and they would come back to a screen they did not leave.
  void didLeave({DateTime? at}) {
    if (!_unlocked) return;
    _leftAt = at ?? DateTime.now();
  }

  /// The app came back. Locks if it was away longer than [lockAfter].
  void didReturn({DateTime? at}) {
    final leftAt = _leftAt;
    _leftAt = null;
    if (leftAt == null) return;
    // A clock that moved backwards while we were away reads as a negative
    // absence. Treat anything not clearly inside the window as outside it.
    final away = (at ?? DateTime.now()).difference(leftAt);
    if (away.isNegative || away >= lockAfter) lock();
  }

  @visibleForTesting
  void resetForTest() {
    _hasPasscode = false;
    _unlocked = false;
    _leftAt = null;
  }
}
