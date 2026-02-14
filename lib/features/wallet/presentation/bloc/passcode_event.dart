import 'package:equatable/equatable.dart';

/// Events for PasscodeBloc
abstract class PasscodeEvent extends Equatable {
  const PasscodeEvent();

  @override
  List<Object?> get props => [];
}

/// Event when user enters a digit
class PasscodeDigitEntered extends PasscodeEvent {
  final String digit;

  const PasscodeDigitEntered(this.digit);

  @override
  List<Object?> get props => [digit];
}

/// Event when user deletes a digit
class PasscodeDigitDeleted extends PasscodeEvent {
  const PasscodeDigitDeleted();
}

/// Event to verify passcode (for unlock mode)
class VerifyPasscodeEvent extends PasscodeEvent {
  final String passcode;

  const VerifyPasscodeEvent(this.passcode);

  @override
  List<Object?> get props => [passcode];
}

/// Event to save passcode (after confirmation)
class SavePasscodeEvent extends PasscodeEvent {
  final String passcode;

  const SavePasscodeEvent(this.passcode);

  @override
  List<Object?> get props => [passcode];
}

/// Event to reset passcode state
class ResetPasscodeEvent extends PasscodeEvent {
  const ResetPasscodeEvent();
}
