import 'package:equatable/equatable.dart';

/// States for PasscodeBloc
abstract class PasscodeState extends Equatable {
  const PasscodeState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no digits entered
class PasscodeInitial extends PasscodeState {
  const PasscodeInitial();
}

/// State with current passcode digits
class PasscodeEntering extends PasscodeState {
  final String passcode;
  final bool isWrong;

  const PasscodeEntering({
    required this.passcode,
    this.isWrong = false,
  });

  @override
  List<Object?> get props => [passcode, isWrong];

  /// Helper to check if passcode is complete (6 digits)
  bool get isComplete => passcode.length == 6;
}

/// Passcode verified successfully (for unlock)
class PasscodeVerified extends PasscodeState {
  const PasscodeVerified();
}

/// Passcode saved successfully
class PasscodeSaved extends PasscodeState {
  const PasscodeSaved();
}

/// Passcode verification failed
class PasscodeVerificationFailed extends PasscodeState {
  const PasscodeVerificationFailed();
}

/// Error state
class PasscodeError extends PasscodeState {
  final String message;

  const PasscodeError(this.message);

  @override
  List<Object?> get props => [message];
}
