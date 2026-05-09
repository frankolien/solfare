import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';

enum _ImportStage { input, analyzing, result }

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final TextEditingController _phraseController = TextEditingController();
  _ImportStage _stage = _ImportStage.input;
  bool _hasError = false;
  String _errorMessage = '';
  bool _walletFound = false;

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final words = _phraseController.text.trim().split(RegExp(r'\s+'));
    return words.length == 12 || words.length == 24;
  }

  void _onConfirm() {
    if (!_isValid) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please enter a valid 12 or 24 word recovery phrase';
      });
      return;
    }
    setState(() {
      _hasError = false;
      _stage = _ImportStage.analyzing;
    });
    final mnemonic = _phraseController.text.trim().toLowerCase();
    context.read<WalletBloc>().add(ImportWalletEvent(mnemonic));
  }

  /// After a successful import, send the user through passcode creation
  /// (and then biometric setup) if they don't already have a passcode set.
  /// Going straight to homepage would leave the wallet accessible with no
  /// lock screen — and on next launch the splash would bounce them back
  /// to onboarding because no passcode exists.
  Future<void> _continueAfterImport() async {
    const storage = FlutterSecureStorage();
    final hasPasscode = await storage.read(key: 'wallet_passcode') != null;
    if (!mounted) return;
    if (hasPasscode) {
      context.go(AppRoutes.homepage);
    } else {
      context.go(AppRoutes.enterPasscode);
    }
  }

  void _onPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _phraseController.text = data!.text!.trim();
      setState(() => _hasError = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WalletBloc, WalletState>(
      listener: (context, state) {
        if (_stage != _ImportStage.analyzing) return;

        if (state is WalletCreated && state.isImported) {
          context.read<WalletBloc>().add(SaveWalletEvent(state.wallet));
        } else if (state is WalletSaved) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              setState(() {
                _walletFound = true;
                _stage = _ImportStage.result;
              });
            }
          });
        } else if (state is WalletError) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              setState(() {
                _walletFound = false;
                _stage = _ImportStage.result;
              });
            }
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _stage == _ImportStage.input
                ? 'Enter your recovery phrase'
                : _stage == _ImportStage.analyzing
                    ? 'Analyzing wallets'
                    : 'Import wallets',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _stage == _ImportStage.input
                ? _buildInputStage()
                : _stage == _ImportStage.analyzing
                    ? _buildAnalyzingStage()
                    : _buildResultStage(),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STAGE 1: Input recovery phrase
  // ─────────────────────────────────────────────
  Widget _buildInputStage() {
    return Padding(
      key: const ValueKey('input'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Enter the 12 or 24 words from your recovery phrase in the right order, separated by spaces.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              fontFamily: 'FKGrotesk',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Text input area
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: _hasError ? Colors.red : Colors.white12,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _phraseController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontFamily: 'FKGrotesk',
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type your recovery phrase',
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 15,
                      fontFamily: 'FKGrotesk',
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: 4,
                  minLines: 3,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    setState(() {
                      _hasError = false;
                    });
                  },
                ),
                const Divider(color: Colors.white12, height: 1),
                // Paste button
                GestureDetector(
                  onTap: _onPaste,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.copy, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Paste',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'FKGrotesk',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Error message
          if (_hasError) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontFamily: 'FKGrotesk',
              ),
            ),
          ],

          const Spacer(),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _phraseController.text.trim().isNotEmpty
                    ? Colors.yellow
                    : const Color(0xFF2A2D35),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: _phraseController.text.trim().isNotEmpty
                  ? _onConfirm
                  : null,
              child: Text(
                'Confirm',
                style: TextStyle(
                  color: _phraseController.text.trim().isNotEmpty
                      ? Colors.black
                      : Colors.grey[500],
                  fontSize: 16,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STAGE 2: Analyzing wallets (shield loader)
  // ─────────────────────────────────────────────
  Widget _buildAnalyzingStage() {
    return Center(
      key: const ValueKey('analyzing'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Lottie.asset(
              'assets/assets/lottie/shield_loader.json',
              repeat: true,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Checking your wallets for existing assets.\nThis should only take a few seconds.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontFamily: 'FKGrotesk',
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STAGE 3: Result — wallet found or not
  // ─────────────────────────────────────────────
  Widget _buildResultStage() {
    return Padding(
      key: const ValueKey('result'),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 3),
          // Wallet icons
          Image.asset(
            'assets/assets/images/empty_wallet.png',
            width: 180,
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.grey[600],
              size: 80,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _walletFound ? 'Wallet imported' : 'No active wallets found',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _walletFound
                ? 'Your wallet has been successfully imported.'
                : 'Wallets are considered active if they hold any assets.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              fontFamily: 'FKGrotesk',
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 4),

          // Quick setup button
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
              onPressed: _continueAfterImport,
              child: const Text(
                'Quick setup',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Advanced button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A2D35),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                // Future: advanced import options (custom derivation paths, etc.)
              },
              child: const Text(
                'Advanced',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
