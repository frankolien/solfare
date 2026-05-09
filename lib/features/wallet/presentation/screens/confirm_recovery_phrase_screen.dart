import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/core/security/secure_screen.dart';
import 'package:solfare/features/wallet/domain/entities/wallet.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';

class ConfirmRecoveryPhraseScreen extends StatefulWidget {
  final Wallet wallet;

  const ConfirmRecoveryPhraseScreen({super.key, required this.wallet});

  @override
  State<ConfirmRecoveryPhraseScreen> createState() =>
      _ConfirmRecoveryPhraseScreenState();
}

class _ConfirmRecoveryPhraseScreenState
    extends State<ConfirmRecoveryPhraseScreen> {
  static const int _totalSteps = 3;

  late final List<String> _words;
  late final List<int> _challengeIndices;
  late final List<List<String>> _options;

  int _currentStep = 0;
  int? _selectedIndex;
  bool _isWrong = false;
  bool _showToast = false;
  bool _isCorrectToast = false;

  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
    _words = widget.wallet.mnemonic.split(' ');
    _challengeIndices = _pickRandomIndices(_words.length, _totalSteps);
    _options = _challengeIndices.map((i) => _buildOptions(i)).toList();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    super.dispose();
  }

  /// Pick [count] unique random indices from 0..[total-1].
  List<int> _pickRandomIndices(int total, int count) {
    final rng = Random.secure();
    final indices = <int>{};
    while (indices.length < count) {
      indices.add(rng.nextInt(total));
    }
    return indices.toList()..sort();
  }

  /// Build 6 shuffled options for the word at [correctIndex].
  List<String> _buildOptions(int correctIndex) {
    final rng = Random.secure();
    final correct = _words[correctIndex];
    final others = <String>{};

    while (others.length < 5) {
      final pick = _words[rng.nextInt(_words.length)];
      if (pick != correct) others.add(pick);
    }

    final opts = [correct, ...others];
    opts.shuffle(rng);
    return opts;
  }

  void _onOptionTap(int optionIndex) {
    if (_selectedIndex != null) return; // already selected

    final correctWord = _words[_challengeIndices[_currentStep]];
    final selected = _options[_currentStep][optionIndex];
    final isCorrect = selected == correctWord;

    setState(() {
      _selectedIndex = optionIndex;
      _isWrong = !isCorrect;
      _showToast = true;
      _isCorrectToast = isCorrect;
    });

    if (isCorrect) {
      // Hide toast after showing success message
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        setState(() {
          _showToast = false;
        });
      });

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        if (_currentStep < _totalSteps - 1) {
          setState(() {
            _currentStep++;
            _selectedIndex = null;
            _isWrong = false;
          });
        } else {
          _saveAndProceed();
        }
      });
    } else {
      // Wrong answer — hide toast and reset after delay
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        setState(() {
          _showToast = false;
          _selectedIndex = null;
          _isWrong = false;
        });
      });
    }
  }

  void _saveAndProceed() {
    // Dispatch event to save wallet using BLoC
    context.read<WalletBloc>().add(SaveWalletEvent(widget.wallet));
  }

  @override
  Widget build(BuildContext context) {
    final wordNumber = _challengeIndices[_currentStep] + 1;

    return BlocListener<WalletBloc, WalletState>(
      // Listen for wallet saved state to navigate
      listener: (context, state) {
        if (state is WalletSaved) {
          // Navigate to passcode screen
          context.push(AppRoutes.enterPasscode);
        } else if (state is WalletError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
                _selectedIndex = null;
                _isWrong = false;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text(
          'Confirm recovery phrase',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        
              const SizedBox(height: 20),

              // Question
              Text(
                'What is the ${_getOrdinal(wordNumber)} word in your recovery phrase?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Options — vertical list with radio buttons
              _buildOptionsList(),

              const Spacer(),

              // Toast message
              if (_showToast) _buildToast(),

             
            ],
          ),
        ),
      ),
      ),
    );
  }

  String _getOrdinal(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  Widget _buildOptionsList() {
    final opts = _options[_currentStep];

    return Column(
      children: List.generate(opts.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 35),
          child: _buildOptionListItem(index, opts[index]),
        );
      }),
    );
  }

  Widget _buildOptionListItem(int index, String word) {
    final isSelected = _selectedIndex == index;

    Color textColor = Colors.white;
    Color radioColor = Colors.white38;

    if (isSelected && !_isWrong) {
      // Correct selection
      textColor = Colors.white;
      radioColor = Colors.yellow;
    } else if (isSelected && _isWrong) {
      // Wrong selection
      textColor = Colors.red;
      radioColor = Colors.red;
    }
    // Security: Don't reveal the correct answer when wrong is selected

    return GestureDetector(
      onTap: () => _onOptionTap(index),
      child: Row(
        children: [
          Expanded(
            child: Text(
              word,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: radioColor,
                width: 2,
              ),
              color: isSelected ? radioColor : Colors.transparent,
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isWrong ? Colors.red : Colors.yellow,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildToast() {
    final remainingSteps = _totalSteps - (_currentStep + 1);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _showToast ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _isCorrectToast
                      ? const Color(0xFF1A4D2E) // Dark green
                      : const Color(0xFF4D1A1A), // Dark red
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _isCorrectToast
                            ? const Color(0xFF4CAF50) // Green
                            : Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isCorrectToast ? Icons.check : Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isCorrectToast ? 'Correct!' : 'Oops, try again!',
                            style: TextStyle(
                              color: _isCorrectToast
                                  ? const Color(0xFF81C784) // Light green
                                  : const Color(0xFFFF6B6B), // Light red
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isCorrectToast
                                ? remainingSteps > 0
                                    ? 'Just ${remainingSteps} more word${remainingSteps > 1 ? 's' : ''} and you are all set.'
                                    : 'All done! Your wallet is ready.'
                                : 'You might want to go back and make sure you have written down the recovery phrase correctly.',
                            style: TextStyle(
                              color: _isCorrectToast
                                  ? const Color(0xFFA5D6A7) // Lighter green
                                  : const Color(0xFFFF8A80), // Lighter red
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
