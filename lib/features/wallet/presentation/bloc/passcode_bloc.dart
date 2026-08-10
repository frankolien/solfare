import 'package:bloc/bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solfare/core/security/app_lock.dart';
import 'package:solfare/core/security/passcode_crypto.dart';
import 'package:solfare/core/security/passcode_gate.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/core/security/secure_store.dart';
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
  static const String _attemptsKey = 'passcode_failed_attempts';
  static const String _lockoutUntilKey = 'passcode_lockout_until';

  PasscodeBloc({
    FlutterSecureStorage? secureStorage,
  })  : _secureStorage = secureStorage ?? SecureStore.instance,
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

  /// Verify the passcode. The rate limit lives in [PasscodeGate] so the
  /// export dialogs, which used to check the hash themselves and so had no
  /// limit at all, share exactly this one.
  Future<void> _onVerifyPasscode(
    VerifyPasscodeEvent event,
    Emitter<PasscodeState> emit,
  ) async {
    try {
      switch (await PasscodeGate.verify(event.passcode)) {
        case PasscodeAccepted():
          // Opens the door for the router. Done here rather than in the
          // screen so the lock cannot be left engaged by a listener that
          // did not run.
          AppLock.instance.unlock();
          emit(const PasscodeVerified());

        case PasscodeUnset():
          emit(const PasscodeError('No passcode set.'));

        case PasscodeLocked(:final remaining):
          emit(PasscodeError(PasscodeGate.describe(remaining)));

        case PasscodeWrong():
          emit(const PasscodeEntering(passcode: '', isWrong: true));
          await Future.delayed(const Duration(milliseconds: 500));
          if (state is PasscodeEntering) {
            emit(const PasscodeEntering(passcode: '', isWrong: false));
          }
      }
    } catch (e) {
      // A raw exception here reaches a user-facing snackbar, and platform
      // errors carry key names and error codes.
      debugLog('[Passcode] verify failed: $e');
      emit(const PasscodeError('Could not check the passcode. Try again.'));
    }
  }

  /// Hash and save passcode to secure storage.
  Future<void> _onSavePasscode(
    SavePasscodeEvent event,
    Emitter<PasscodeState> emit,
  ) async {
    try {
      final hashed = await PasscodeCrypto.hash(event.passcode);
      await _secureStorage.write(key: _passcodeKey, value: hashed);
      await _secureStorage.delete(key: _attemptsKey);
      await _secureStorage.delete(key: _lockoutUntilKey);
      // Setting a passcode both creates the lock and satisfies it — the user
      // is holding the phone and has just typed it twice.
      AppLock.instance.adopt();
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
      emit(PasscodeEntering(passcode: currentState.passcode, isWrong: true));
      // Hold the wrong-state long enough for the haptic + red flash to land.
      await Future.delayed(const Duration(milliseconds: 800));
      if (state is PasscodeEntering) {
        emit(const PasscodeInitial());
      }
    }
  }
}
