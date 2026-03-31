import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
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

  @override
  void initState() {
    super.initState();
    
    // Reset passcode state when entering confirm mode
    // This ensures the state is clean when navigating from enter to confirm
    if (widget.mode == PasscodeMode.confirm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<PasscodeBloc>().add(const ResetPasscodeEvent());
        }
      });
    }
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
              // Handle side effects (navigation) in listener
              if (state is PasscodeVerified) {
                // Passcode verified - navigate to homepage
                if (!_hasNavigated && mounted) {
                  _hasNavigated = true;
                  Future.microtask(() {
                    if (mounted) {
                      context.go(AppRoutes.homepage);
                    }
                  });
                }
              } else if (state is PasscodeSaved) {
                // Passcode saved - navigate to biometric setup
                if (!_hasNavigated && mounted) {
                  _hasNavigated = true;
                  Future.microtask(() {
                    if (mounted) {
                      context.go(AppRoutes.biometricSetup);
                    }
                  });
                }
              } else if (state is PasscodeEntering && state.isComplete && !_hasNavigated) {
                // Passcode is complete - handle based on mode
                // Only process if we haven't navigated yet
                if (widget.mode == PasscodeMode.unlock) {
                  // Verify passcode
                  context.read<PasscodeBloc>().add(
                        VerifyPasscodeEvent(state.passcode),
                      );
                } else if (widget.mode == PasscodeMode.enter) {
                  // Navigate to confirm screen
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted && !_hasNavigated) {
                      context.push(
                        AppRoutes.confirmPasscode,
                        extra: state.passcode,
                      );
                    }
                  });
                } else if (widget.mode == PasscodeMode.confirm) {
                  // Check if it matches initial passcode
                  if (state.passcode == widget.initialPasscode) {
                    // Save passcode - this will emit PasscodeSaved state
                    context.read<PasscodeBloc>().add(
                          SavePasscodeEvent(state.passcode),
                        );
                  } else {
                    // Wrong passcode - show error and reset
                    context.read<PasscodeBloc>().add(
                          const PasscodeWrongEvent(),
                        );
                  }
                }
              }
            },
            builder: (context, state) {
              // Get current passcode from state
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

                    // Passcode indicators (6 circles)
                    Expanded(
                      flex: 3,
                      child: _buildPasscodeIndicators(passcode, isWrong),
                    ),

                    const Spacer(),

                    // Numeric keypad
                    _buildKeypad(),

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
          // Rows 1-3: Numbers 1-9
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

          // Row 4: 0 and delete
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
    
    // Dispatch event to BLoC - BLoC will update state
    context.read<PasscodeBloc>().add(PasscodeDigitEntered(digit));
  }

  void _onDeletePressed() {
    HapticFeedback.lightImpact();
    
    // Dispatch event to BLoC - BLoC will update state
    context.read<PasscodeBloc>().add(const PasscodeDigitDeleted());
  }
}
