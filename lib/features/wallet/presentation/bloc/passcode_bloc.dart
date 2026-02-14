import 'package:bloc/bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  PasscodeBloc({
    FlutterSecureStorage? secureStorage,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        super(const PasscodeInitial()) {
    on<PasscodeDigitEntered>(_onDigitEntered);
    on<PasscodeDigitDeleted>(_onDigitDeleted);
    on<VerifyPasscodeEvent>(_onVerifyPasscode);
    on<SavePasscodeEvent>(_onSavePasscode);
    on<ResetPasscodeEvent>(_onResetPasscode);
  }

  /// Handle digit entry
  void _onDigitEntered(
    PasscodeDigitEntered event,
    Emitter<PasscodeState> emit,
  ) {
    final currentState = state;
    
    if (currentState is PasscodeEntering) {
      final newPasscode = currentState.passcode + event.digit;
      
      // If passcode is complete, emit state with isComplete flag
      emit(PasscodeEntering(
        passcode: newPasscode,
        isWrong: false,
      ));
    } else {
      // Start entering passcode
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

  /// Verify passcode against stored value
  Future<void> _onVerifyPasscode(
    VerifyPasscodeEvent event,
    Emitter<PasscodeState> emit,
  ) async {
    try {
      final storedPasscode = await _secureStorage.read(key: _passcodeKey);
      
      if (event.passcode == storedPasscode) {
        emit(const PasscodeVerified());
      } else {
        // Show wrong passcode state, then reset
        emit(const PasscodeEntering(
          passcode: '',
          isWrong: true,
        ));
        
        // After delay, reset to allow re-entry
        await Future.delayed(const Duration(milliseconds: 500));
        if (state is PasscodeEntering) {
          emit(const PasscodeEntering(
            passcode: '',
            isWrong: false,
          ));
        }
      }
    } catch (e) {
      emit(PasscodeError(e.toString()));
    }
  }

  /// Save passcode to secure storage
  Future<void> _onSavePasscode(
    SavePasscodeEvent event,
    Emitter<PasscodeState> emit,
  ) async {
    try {
      await _secureStorage.write(key: _passcodeKey, value: event.passcode);
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
}
