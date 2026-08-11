import 'package:bloc/bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solfare/core/security/app_lock.dart';
import 'package:solfare/core/security/biometric_lock.dart';
import 'package:solfare/core/security/passcode_crypto.dart';
import 'package:solfare/core/security/passcode_gate.dart';
import 'package:solfare/core/security/wallet_key.dart';
import 'package:solfare/features/wallet/data/datasource/wallet_accounts_store.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/core/security/secure_store.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_state.dart';

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
    on<BiometricUnlockRequested>(_onBiometricUnlock);
  }

  void _onDigitEntered(
    PasscodeDigitEntered event,
    Emitter<PasscodeState> emit,
  ) {
    final currentState = state;
    
    if (currentState is PasscodeEntering) {
      if (currentState.passcode.length >= 6) {
        return;
      }
      
      final newPasscode = currentState.passcode + event.digit;
      
      emit(PasscodeEntering(
        passcode: newPasscode,
        isWrong: false,
      ));
    } else {
      emit(PasscodeEntering(
        passcode: event.digit,
        isWrong: false,
      ));
    }
  }

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

  Future<void> _onVerifyPasscode(
    VerifyPasscodeEvent event,
    Emitter<PasscodeState> emit,
  ) async {
    try {
      switch (await PasscodeGate.verify(event.passcode)) {
        case PasscodeAccepted():
          // Opens the door for the router.
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

  Future<void> _onBiometricUnlock(
    BiometricUnlockRequested event,
    Emitter<PasscodeState> emit,
  ) async {
    final key = await BiometricLock.unlock();
    // Cancelled, failed, or the OS invalidated the item because the enrolled
    // biometrics changed. The keypad is already on screen either way.
    if (key == null) return;

    await PasscodeGate.holdAndMigrate(key);
    AppLock.instance.unlock();
    emit(const PasscodeVerified());
  }

  Future<void> _onSavePasscode(
    SavePasscodeEvent event,
    Emitter<PasscodeState> emit,
  ) async {
    try {
      // Digest first, then wrap — the same order the unlock path uses, and for
      // the same reason: writing it makes the salt durable, so the key is
      // reproducible if anything below fails.
      final made = await PasscodeCrypto.create(event.passcode);
      await _secureStorage.write(key: _passcodeKey, value: made.stored);
      await _secureStorage.delete(key: _attemptsKey);
      await _secureStorage.delete(key: _lockoutUntilKey);

      // Onboarding writes the wallet before the passcode exists, so this is the
      // first moment there is a key to wrap that mnemonic with.
      WalletKey.hold(made.keys.wrapKey);
      try {
        await WalletAccountsStore().wrapPlaintextMnemonics(made.keys.wrapKey);
      } catch (e) {
        debugLog('[Passcode] could not wrap on setup: $e');
      }

      // A changed passcode is a changed wrapKey, and a stored one that no
      // longer decrypts surfaces as an unreadable recovery phrase. No-op when
      // biometrics was never turned on.
      await BiometricLock.rekey(made.keys.wrapKey);

      // Setting a passcode both creates the lock and satisfies it — the user is
      // holding the phone and has just typed it twice.
      AppLock.instance.adopt();
      emit(const PasscodeSaved());
    } catch (e) {
      emit(PasscodeError(e.toString()));
    }
  }

  void _onResetPasscode(
    ResetPasscodeEvent event,
    Emitter<PasscodeState> emit,
  ) {
    emit(const PasscodeInitial());
  }

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
