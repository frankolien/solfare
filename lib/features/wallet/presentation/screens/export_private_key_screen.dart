import 'dart:ui';
import 'package:bs58/bs58.dart';
import 'package:flutter/material.dart';
import 'package:solfare/core/security/passcode_crypto.dart';
import 'package:solfare/core/security/secure_clipboard.dart';
import 'package:solfare/core/security/secure_screen.dart';
import 'package:solfare/core/security/secure_store.dart';
import 'package:solfare/core/util/copied_toast.dart';
import 'package:solfare/core/wallet/active_wallet.dart';
import 'package:solfare/core/wallet/keyring.dart';

enum _KeyFormat { base58, array }

class ExportPrivateKeyScreen extends StatefulWidget {
  const ExportPrivateKeyScreen({super.key});

  @override
  State<ExportPrivateKeyScreen> createState() => _ExportPrivateKeyScreenState();
}

class _ExportPrivateKeyScreenState extends State<ExportPrivateKeyScreen> {
  final _storage = SecureStore.instance;
  String? _privateKeyBase58;
  List<int>? _privateKeyBytes;
  bool _isRevealed = false;
  bool _isLoading = true;
  _KeyFormat _format = _KeyFormat.base58;

  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
    _loadKey();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    final bytes = _privateKeyBytes;
    if (bytes != null) {
      try {
        for (var i = 0; i < bytes.length; i++) {
          bytes[i] = 0;
        }
      } catch (_) {}
    }
    _privateKeyBytes = null;
    _privateKeyBase58 = null;
    super.dispose();
  }

  Future<void> _loadKey() async {
    final mnemonic = await ActiveWallet.mnemonic();
    if (mnemonic == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final privateKeyBytes = await Keyring.privateKeyBytes(mnemonic);
      final privateKeyBase58 = base58.encode(privateKeyBytes);
      if (!mounted) return;
      setState(() {
        _privateKeyBase58 = privateKeyBase58;
        _privateKeyBytes = privateKeyBytes;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _displayKey {
    if (_format == _KeyFormat.base58) {
      return _privateKeyBase58 ?? 'Key not available';
    } else {
      if (_privateKeyBytes != null) {
        return '[${_privateKeyBytes!.join(', ')}]';
      }
      return 'Array format not available';
    }
  }

  String get _formatDescription {
    if (_format == _KeyFormat.base58) {
      return 'Base58 format, widely supported by most wallets and apps.';
    } else {
      return 'Raw byte array format, used by some developer tools.';
    }
  }

  void _toggleReveal() {
    if (_isRevealed) {
      setState(() => _isRevealed = false);
      return;
    }
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
              Text(
                'Enter your 6-digit passcode to reveal your private key.',
                style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'FKGrotesk', height: 1.4),
              ),
              const SizedBox(height: 16),
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
              _buildMiniKeypad(entered, (val) async {
                setDialogState(() => entered = val);
                if (val.length == 6) {
                  final stored = await _storage.read(key: 'wallet_passcode');
                  if (!context.mounted) return;
                  if (stored != null && PasscodeCrypto.verify(val, stored)) {
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

  void _showFormatPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1F26),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
            ),
            _formatOption('Base 58 (default)', _KeyFormat.base58),
            const SizedBox(height: 4),
            _formatOption('Array', _KeyFormat.array),
          ],
        ),
      ),
    );
  }

  Widget _formatOption(String label, _KeyFormat format) {
    return GestureDetector(
      onTap: () {
        setState(() => _format = format);
        Navigator.pop(context);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w400)),
            const Spacer(),
            if (_format == format)
              const Icon(Icons.check, color: Colors.yellow, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0b12),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      child: Text(
                        'Export private key',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Format selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Format', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                  GestureDetector(
                    onTap: _showFormatPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1F26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _format == _KeyFormat.base58 ? 'Base 58 (default)' : 'Array',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'FKGrotesk'),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.unfold_more, color: Colors.grey[500], size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.white.withValues(alpha: 0.08), height: 24),
            ),

            // Format description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _formatDescription,
                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk'),
              ),
            ),

            const SizedBox(height: 20),

            // Key display
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: Colors.yellow, strokeWidth: 2))
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  constraints: const BoxConstraints(minHeight: 120),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      _isRevealed
                          ? SelectableText(
                              _displayKey,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w400, height: 1.6),
                            )
                          : ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Text(
                                _privateKeyBase58 ?? 'xxxxxxxxxxxxxxxxxxxxxxxx',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w400, height: 1.6),
                              ),
                            ),
                      if (_isRevealed) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white10, height: 1),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            SecureClipboard.copySensitive(_displayKey);
                            showCopiedToast(context);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.copy, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              const Text('Copy', style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

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
                            'Never share your private key',
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
