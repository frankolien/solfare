import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/core/security/biometric_lock.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_state.dart';

enum PasscodeMode { enter, confirm, unlock }

class PasscodeScreen extends StatefulWidget {
  final PasscodeMode mode;
  final String? initialPasscode;

  const PasscodeScreen({
    super.key,
    required this.mode,
    this.initialPasscode,
  });

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> {
  bool _hasNavigated = false; // Prevent multiple navigations

  // Null until we know there is a biometric door to offer, so the button never
  // appears on a device that would only fail.
  String? _biometricLabel;

  @override
  void initState() {
    super.initState();
    // The bloc carries leftover entered digits when arriving from the enter
    // step.
    if (widget.mode == PasscodeMode.confirm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<PasscodeBloc>().add(const ResetPasscodeEvent());
        }
      });
    }
    if (widget.mode == PasscodeMode.unlock) unawaited(_offerBiometrics());
  }

  // Prompts once on arrival, then leaves the button for a retry. A user who
  // dismisses Face ID wants the keypad, not the same sheet again.
  Future<void> _offerBiometrics() async {
    if (!await BiometricLock.isEnabled()) return;
    final label = await BiometricLock.label();
    if (!mounted) return;
    setState(() => _biometricLabel = label);
    _promptBiometrics();
  }

  void _promptBiometrics() {
    if (_hasNavigated) return;
    context.read<PasscodeBloc>().add(const BiometricUnlockRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.mode == PasscodeMode.enter
              ? 'Enter New Passcode'
              : widget.mode == PasscodeMode.confirm
                  ? 'Confirm Passcode'
                  : 'Enter Passcode',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: KeyboardVisibilityBuilder(
        builder: (context, isKeyboardVisible) {
          return BlocConsumer<PasscodeBloc, PasscodeState>(
            listener: (context, state) {
              if (state is PasscodeVerified) {
                if (!_hasNavigated && mounted) {
                  _hasNavigated = true;
                  Future.microtask(() {
                    if (context.mounted) context.go(AppRoutes.homepage);
                  });
                }
              } else if (state is PasscodeSaved) {
                if (!_hasNavigated && mounted) {
                  _hasNavigated = true;
                  Future.microtask(() {
                    if (context.mounted) context.go(AppRoutes.biometricSetup);
                  });
                }
              } else if (state is PasscodeError) {
                // Surface verification failures and lockouts.
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: Colors.red[700],
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    ),
                  );
              } else if (state is PasscodeEntering && state.isWrong) {
                // Buzz so the user knows the keypad reset wasn't a tap they
                // missed.
                HapticFeedback.heavyImpact();
              } else if (state is PasscodeEntering && state.isComplete && !_hasNavigated) {
                if (widget.mode == PasscodeMode.unlock) {
                  context.read<PasscodeBloc>().add(
                        VerifyPasscodeEvent(state.passcode),
                      );
                } else if (widget.mode == PasscodeMode.enter) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (context.mounted && !_hasNavigated) {
                      context.push(
                        AppRoutes.confirmPasscode,
                        extra: state.passcode,
                      );
                    }
                  });
                } else if (widget.mode == PasscodeMode.confirm) {
                  if (state.passcode == widget.initialPasscode) {
                    context.read<PasscodeBloc>().add(
                          SavePasscodeEvent(state.passcode),
                        );
                  } else {
                    context.read<PasscodeBloc>().add(
                          const PasscodeWrongEvent(),
                        );
                  }
                }
              }
            },
            builder: (context, state) {
              String passcode = '';
              bool isWrong = false;

              if (state is PasscodeEntering) {
                passcode = state.passcode;
                isWrong = state.isWrong;
              }

              return SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    Expanded(
                      flex: 3,
                      child: _buildPasscodeIndicators(passcode, isWrong),
                    ),

                    if (widget.mode == PasscodeMode.enter)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 44),
                        child: Text(
                          'This passcode encrypts your wallet on this device. '
                          'If you forget it, only your recovery phrase can '
                          'restore access.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            fontFamily: 'FKGrotesk',
                            height: 1.6,
                          ),
                        ),
                      ),

                    const Spacer(),

                    _buildKeypad(),

                    if (_biometricLabel != null) ...[
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: _promptBiometrics,
                        icon: const Icon(Icons.fingerprint,
                            color: Colors.white, size: 22),
                        label: Text(
                          'Unlock with $_biometricLabel',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: 'FKGrotesk',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: isKeyboardVisible ? 20 : 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPasscodeIndicators(String passcode, bool isWrong) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final isFilled = index < passcode.length;
        final isWrongIndicator = isWrong && index == passcode.length - 1;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (isWrongIndicator ? Colors.red : Colors.white)
                : Colors.transparent,
            border: Border.all(
              color: isFilled
                  ? (isWrongIndicator ? Colors.red : Colors.white)
                  : Colors.white38,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          for (int row = 0; row < 3; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int col = 0; col < 3; col++)
                    _buildKeypadButton('${row * 3 + col + 1}'),
                ],
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              
              const SizedBox(width: 80), // Spacer for alignment
              _buildKeypadButton('0'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: _buildDeleteButton(),
              ),
            ],
          ),
          
        ],
      ),
    );
  }

  Widget _buildKeypadButton(String digit) {
    return GestureDetector(
      onTap: () => _onDigitPressed(digit),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[900],
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: _onDeletePressed,
      child: const Icon(
        Icons.backspace_outlined,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  void _onDigitPressed(String digit) {
    HapticFeedback.lightImpact();
    
    context.read<PasscodeBloc>().add(PasscodeDigitEntered(digit));
  }

  void _onDeletePressed() {
    HapticFeedback.lightImpact();
    
    context.read<PasscodeBloc>().add(const PasscodeDigitDeleted());
  }
}
