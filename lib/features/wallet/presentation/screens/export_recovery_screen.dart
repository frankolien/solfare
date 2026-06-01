import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solfare/core/security/passcode_crypto.dart';
import 'package:solfare/core/security/secure_clipboard.dart';
import 'package:solfare/core/security/secure_screen.dart';
import 'package:solfare/core/wallet/active_wallet.dart';
import 'package:solfare/core/util/copied_toast.dart';

class ExportRecoveryScreen extends StatefulWidget {
  const ExportRecoveryScreen({super.key});

  @override
  State<ExportRecoveryScreen> createState() => _ExportRecoveryScreenState();
}

class _ExportRecoveryScreenState extends State<ExportRecoveryScreen> {
  final _storage = const FlutterSecureStorage();
  String? _mnemonic;
  bool _isRevealed = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
    _loadMnemonic();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    super.dispose();
  }

  Future<void> _loadMnemonic() async {
    final mnemonic = await ActiveWallet.mnemonic();
    if (mounted) {
      setState(() {
        _mnemonic = mnemonic;
        _isLoading = false;
      });
    }
  }

  void _toggleReveal() {
    if (_isRevealed) {
      setState(() => _isRevealed = false);
      return;
    }
    // Ask for passcode before revealing
    _showPasscodeDialog();
  }

  void _showPasscodeDialog() {
    String entered = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1F26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Enter Passcode', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter your 6-digit passcode to reveal your recovery phrase.',
                style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'FKGrotesk', height: 1.4)),
              const SizedBox(height: 16),
              // Passcode dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => Container(
                  width: 12, height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < entered.length ? Colors.yellow : Colors.grey[700],
                  ),
                )),
              ),
              const SizedBox(height: 20),
              // Number pad
              _buildMiniKeypad(entered, (val) async {
                setDialogState(() => entered = val);
                if (val.length == 6) {
                  final stored = await _storage.read(key: 'wallet_passcode');
                  final ok = stored != null && await PasscodeCrypto.verify(val, stored);
                  if (!mounted || !context.mounted) return;
                  if (ok) {
                    Navigator.pop(ctx);
                    setState(() => _isRevealed = true);
                  } else {
                    setDialogState(() => entered = '');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Wrong passcode'), backgroundColor: Colors.red, duration: Duration(seconds: 1)),
                    );
                  }
                }
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'FKGrotesk')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniKeypad(String current, ValueChanged<String> onUpdate) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 10,
      children: [
        ...List.generate(9, (i) => _keypadButton('${i + 1}', current, onUpdate)),
        const SizedBox(width: 56),
        _keypadButton('0', current, onUpdate),
        GestureDetector(
          onTap: () {
            if (current.isNotEmpty) {
              onUpdate(current.substring(0, current.length - 1));
            }
          },
          child: Container(
            width: 56, height: 40,
            alignment: Alignment.center,
            child: const Icon(Icons.backspace_outlined, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _keypadButton(String digit, String current, ValueChanged<String> onUpdate) {
    return GestureDetector(
      onTap: () {
        if (current.length < 6) {
          onUpdate(current + digit);
        }
      },
      child: Container(
        width: 56, height: 40,
        alignment: Alignment.center,
        child: Text(digit, style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0b12),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Export recovery phrase', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: Colors.yellow, strokeWidth: 2))
            else if (_mnemonic != null) ...[
              // Phrase card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      // Phrase text — blurred or visible
                      _isRevealed
                          ? Text(
                              _mnemonic!,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w400, height: 1.6),
                            )
                          : ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Text(
                                _mnemonic!,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w400, height: 1.6),
                              ),
                            ),

                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 12),

                      // Copy button
                      GestureDetector(
                        onTap: _isRevealed
                            ? () {
                                SecureClipboard.copySensitive(_mnemonic!);
                                showCopiedToast(context);
                              }
                            : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.copy, color: _isRevealed ? Colors.white : Colors.grey[600], size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Copy',
                              style: TextStyle(color: _isRevealed ? Colors.white : Colors.grey[600], fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const Spacer(),

            // Warning banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.yellow.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.priority_high, color: Colors.black, size: 14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Never share your recovery phrase',
                            style: TextStyle(color: Colors.yellow, fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Anyone that has it can gain full control of your wallet. Our support team will never ask for it.',
                            style: TextStyle(color: Colors.grey[400], fontSize: 10, fontFamily: 'FKGrotesk', height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  onPressed: _toggleReveal,
                  child: Text(
                    _isRevealed ? 'Hide' : 'Show',
                    style: const TextStyle(color: Colors.black, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
