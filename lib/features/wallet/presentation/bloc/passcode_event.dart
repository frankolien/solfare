import 'package:equatable/equatable.dart';

abstract class PasscodeEvent extends Equatable {
  const PasscodeEvent();

  @override
  List<Object?> get props => [];
}

class PasscodeDigitEntered extends PasscodeEvent {
  final String digit;

  const PasscodeDigitEntered(this.digit);

  @override
  List<Object?> get props => [digit];
}

class PasscodeDigitDeleted extends PasscodeEvent {
  const PasscodeDigitDeleted();
}

class VerifyPasscodeEvent extends PasscodeEvent {
  final String passcode;

  const VerifyPasscodeEvent(this.passcode);

  @override
  List<Object?> get props => [passcode];
}

class SavePasscodeEvent extends PasscodeEvent {
  final String passcode;

  const SavePasscodeEvent(this.passcode);

  @override
  List<Object?> get props => [passcode];
}

class ResetPasscodeEvent extends PasscodeEvent {
  const ResetPasscodeEvent();
}

class PasscodeWrongEvent extends PasscodeEvent {
  const PasscodeWrongEvent();
}

/// Offer the biometric door instead of the keypad.
class BiometricUnlockRequested extends PasscodeEvent {
  const BiometricUnlockRequested();
}
