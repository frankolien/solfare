import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/core/security/secure_screen.dart';
import 'package:solfare/features/wallet/domain/entities/wallet.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  bool _isRevealed = false;
  Wallet? _currentWallet;

  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
    context.read<WalletBloc>().add(const CreateWalletEvent());
  }

  @override
  void dispose() {
    SecureScreen.disable();
    super.dispose();
  }

  void _handleSaveWallet() {
    final state = context.read<WalletBloc>().state;
    if (state is WalletCreated) {
      context.read<WalletBloc>().add(SaveWalletEvent(state.wallet));
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
        title: const Text(
          'Your recovery phrase',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: BlocConsumer<WalletBloc, WalletState>(
          listener: (context, state) {
            if (state is WalletCreated) {
              _currentWallet = state.wallet;
            } else if (state is WalletSaved) {
              context.push(AppRoutes.enterPasscode);
            } else if (state is WalletError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          builder: (context, state) {
            if (state is WalletLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.yellow),
              );
            } else if (state is WalletError) {
              return _buildError(state.message);
            } else if (state is WalletCreated) {
              return _isRevealed
                  ? _buildRevealedView(state.wallet)
                  : _buildBlurredView(state.wallet);
            } else {
              return const Center(
                child: CircularProgressIndicator(color: Colors.yellow),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildBlurredView(Wallet wallet) {
    final words = wallet.mnemonic.split(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Blurred mnemonic card (wraps content)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                // Blurred word grid
                Stack(
                  children: [
                    // The actual grid (blurred)
                    _buildWordGrid(words, blurred: true),

                    // Overlay with text
                    Positioned.fill(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Write it down',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Make sure no one is watching, this phrase\ngives full access to your wallet. Never share\nit with anyone.',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                                height: 1.5,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                GestureDetector(
                  onTap: () => setState(() => _isRevealed = true),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.visibility_outlined,
                          color: Colors.grey[400], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Show',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Continue button (disabled)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: null,
              child: Text(
                'Continue',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Skip for now
          TextButton(
            onPressed: _handleSaveWallet,
            child: const Text(
              'Skip for now',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // REVEALED STATE (after tapping Show — matches Figma right screen)
  // ──────────────────────────────────────────────
  Widget _buildRevealedView(Wallet wallet) {
    final words = wallet.mnemonic.split(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Mnemonic card (wraps content)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            decoration: BoxDecoration(
              color: Colors.grey[900]?.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                _buildWordGrid(words, blurred: false),

                const SizedBox(height: 20),

                // Copy button
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: wallet.mnemonic));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Recovery phrase copied!')),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.copy, color: Colors.grey[400], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Copy',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Continue button (active)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                context.push(
                  AppRoutes.confirmRecoveryPhrase,
                  extra: wallet,
                );
              },
              child: const Text(
                'Continue',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Skip for now
          TextButton(
            onPressed: _handleSaveWallet,
            child: const Text(
              'Skip for now',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // WORD GRID — 2 columns, 6 rows (matching Figma layout)
  // ──────────────────────────────────────────────
  Widget _buildWordGrid(List<String> words, {required bool blurred}) {
    final halfLength = (words.length / 2).ceil();
    final leftWords = words.sublist(0, halfLength);
    final rightWords = words.sublist(halfLength);

    Widget grid = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildWordColumn(leftWords, startIndex: 1)),
          VerticalDivider(
            color: Colors.white12,
            width: 32,
            thickness: 1,
          ),
          Expanded(
              child:
                  _buildWordColumn(rightWords, startIndex: halfLength + 1)),
        ],
      ),
    );

    if (blurred) {
      return ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: grid,
      );
    }

    return grid;
  }

  Widget _buildWordColumn(List<String> words, {required int startIndex}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(words.length, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${startIndex + index}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                words[index],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ──────────────────────────────────────────────
  // ERROR STATE
  // ──────────────────────────────────────────────
  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Dispatch event to retry wallet creation
                context.read<WalletBloc>().add(const CreateWalletEvent());
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
