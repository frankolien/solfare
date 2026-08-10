import 'package:flutter/foundation.dart';
import 'package:solfare/core/security/secure_store.dart';
import 'package:solfare/core/security/wallet_key.dart';

/// Whether the app is currently allowed to be used.
class AppLock extends ChangeNotifier {
  AppLock._();

  static final AppLock instance = AppLock._();

  /// The key the passcode hash is stored under.
  static const passcodeKey = 'wallet_passcode';

  /// How long the app may sit in the background before it re-locks.
  static const lockAfter = Duration(seconds: 60);

  bool _hasPasscode = false;
  bool _unlocked = false;
  DateTime? _leftAt;

  /// True when a passcode exists and it has not been entered this session.
  bool get isLocked => _hasPasscode && !_unlocked;

  /// Whether the user has set a passcode at all.
  bool get hasPasscode => _hasPasscode;

  /// Reads the stored passcode once, before the first frame.
  Future<void> load() async {
    try {
      _hasPasscode = await SecureStore.instance.read(key: passcodeKey) != null;
    } catch (_) {
      // A storage read that fails is not evidence there is no passcode.
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
    WalletKey.clear();
    notifyListeners();
  }

  /// Require the passcode again on the next navigation.
  void lock() {
    _leftAt = null;
    WalletKey.clear();
    if (!_unlocked) return;
    _unlocked = false;
    notifyListeners();
  }

  /// The app went to the background. Only the time is recorded.
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
    // absence.
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
