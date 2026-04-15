import 'package:bloc/bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solfare/core/security/passcode_crypto.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_state.dart';

/// BLoC for passcode management
/// 
/// Handles:
/// - Entering passcode digits
/// - Verifying passcode (unlock mode)
/// - Saving passcode (setup mode)
class PasscodeBloc extends Bloc<PasscodeEvent, PasscodeState> {
  final FlutterSecureStorage _secureStorage;
  static const String _passcodeKey = 'wallet_passcode';
  static const int _maxAttempts = 3;
  static const Duration _lockoutDuration = Duration(seconds: 30);
  static const String _attemptsKey = 'passcode_failed_attempts';
  static const String _lockoutUntilKey = 'passcode_lockout_until';

  PasscodeBloc({
    FlutterSecureStorage? secureStorage,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        super(const PasscodeInitial()) {
    on<PasscodeDigitEntered>(_onDigitEntered);
    on<PasscodeDigitDeleted>(_onDigitDeleted);
    on<VerifyPasscodeEvent>(_onVerifyPasscode);
    on<SavePasscodeEvent>(_onSavePasscode);
    on<ResetPasscodeEvent>(_onResetPasscode);
    on<PasscodeWrongEvent>(_onPasscodeWrong);
  }

  /// Handle digit entry
  void _onDigitEntered(
    PasscodeDigitEntered event,
    Emitter<PasscodeState> emit,
  ) {
    final currentState = state;
    
    if (currentState is PasscodeEntering) {
      // Don't allow more digits if passcode is already complete
      if (currentState.passcode.length >= 6) {
        return;
      }
      
      final newPasscode = currentState.passcode + event.digit;
      
      // Emit state with updated passcode
      emit(PasscodeEntering(
        passcode: newPasscode,
        isWrong: false,
      ));
    } else {
      // Start entering passcode (from initial or other states)
      emit(PasscodeEntering(
        passcode: event.digit,
        isWrong: false,
      ));
    }
  }

  /// Handle digit deletion
  void _onDigitDeleted(
    PasscodeDigitDeleted event,
    Emitter<PasscodeState> emit,
  ) {
    final currentState = state;
    
    if (currentState is PasscodeEntering && currentState.passcode.isNotEmpty) {
      final newPasscode = currentState.passcode.substring(
        0,
        currentState.passcode.length - 1,
      );
      
      emit(PasscodeEntering(
        passcode: newPasscode,
        isWrong: false,
      ));
    }
  }

  /// Verify passcode against stored hash. Applies rate limiting: after
  /// [_maxAttempts] wrong entries the passcode is locked for
  /// [_lockoutDuration] to mitigate brute-force on the 6-digit space.
  Future<void> _onVerifyPasscode(
    VerifyPasscodeEvent event,
    Emitter<PasscodeState> emit,
  ) async {
    try {
      // Lockout check first.
      final lockoutUntilMs = int.tryParse(
              await _secureStorage.read(key: _lockoutUntilKey) ?? '') ??
          0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (lockoutUntilMs > nowMs) {
        final secondsLeft = ((lockoutUntilMs - nowMs) / 1000).ceil();
        emit(PasscodeError('Too many attempts. Try again in $secondsLeft s.'));
        return;
      }

      final storedHash = await _secureStorage.read(key: _passcodeKey);
      if (storedHash == null) {
        emit(const PasscodeError('No passcode set.'));
        return;
      }

      final ok = PasscodeCrypto.verify(event.passcode, storedHash);
      if (ok) {
        // Migrate legacy plaintext installs to a hashed format silently.
        if (PasscodeCrypto.isLegacyPlaintext(storedHash)) {
          final upgraded = PasscodeCrypto.hash(event.passcode);
          await _secureStorage.write(key: _passcodeKey, value: upgraded);
        }
        await _secureStorage.delete(key: _attemptsKey);
        await _secureStorage.delete(key: _lockoutUntilKey);
        emit(const PasscodeVerified());
        return;
      }

      // Wrong: bump attempt counter; lock when threshold exceeded.
      final attempts = (int.tryParse(
                  await _secureStorage.read(key: _attemptsKey) ?? '') ??
              0) +
          1;
      if (attempts >= _maxAttempts) {
        final until = nowMs + _lockoutDuration.inMilliseconds;
        await _secureStorage.write(key: _lockoutUntilKey, value: until.toString());
        await _secureStorage.write(key: _attemptsKey, value: '0');
        emit(PasscodeError(
            'Too many attempts. Locked for ${_lockoutDuration.inSeconds}s.'));
        return;
      }
      await _secureStorage.write(key: _attemptsKey, value: attempts.toString());

      emit(const PasscodeEntering(passcode: '', isWrong: true));
      await Future.delayed(const Duration(milliseconds: 500));
      if (state is PasscodeEntering) {
        emit(const PasscodeEntering(passcode: '', isWrong: false));
      }
    } catch (e) {
      emit(PasscodeError(e.toString()));
    }
  }

  /// Hash and save passcode to secure storage.
  Future<void> _onSavePasscode(
    SavePasscodeEvent event,
    Emitter<PasscodeState> emit,
  ) async {
    try {
      final hashed = PasscodeCrypto.hash(event.passcode);
      await _secureStorage.write(key: _passcodeKey, value: hashed);
      await _secureStorage.delete(key: _attemptsKey);
      await _secureStorage.delete(key: _lockoutUntilKey);
      emit(const PasscodeSaved());
    } catch (e) {
      emit(PasscodeError(e.toString()));
    }
  }

  /// Reset passcode state
  void _onResetPasscode(
    ResetPasscodeEvent event,
    Emitter<PasscodeState> emit,
  ) {
    emit(const PasscodeInitial());
  }

  /// Handle wrong passcode (for confirm mode)
  Future<void> _onPasscodeWrong(
    PasscodeWrongEvent event,
    Emitter<PasscodeState> emit,
  ) async {
    final currentState = state;
    if (currentState is PasscodeEntering) {
      // Show wrong state
      emit(PasscodeEntering(
        passcode: currentState.passcode,
        isWrong: true,
      ));
      
      // Reset after delay
      await Future.delayed(const Duration(milliseconds: 800));
      if (state is PasscodeEntering) {
        emit(const PasscodeInitial());
      }
    }
  }
}
