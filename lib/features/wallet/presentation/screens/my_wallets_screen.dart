import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfare/core/util/copied_toast.dart';
import 'package:solfare/features/wallet/presentation/screens/edit_background_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/export_private_key_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/export_recovery_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/rename_wallet_screen.dart';

class MyWalletsScreen extends StatefulWidget {
  final String walletAddress;
  final double balanceUsd;
  final double priceChange24h;
  final String walletName;
  final String cardBackground;

  const MyWalletsScreen({
    super.key,
    required this.walletAddress,
    this.balanceUsd = 0.0,
    this.priceChange24h = 0.0,
    this.walletName = 'Main Wallet',
    this.cardBackground = 'card_1.png',
  });

  @override
  State<MyWalletsScreen> createState() => _MyWalletsScreenState();
}

class _MyWalletsScreenState extends State<MyWalletsScreen> {
  late String _walletName;
  late String _selectedCard;

  @override
  void initState() {
    super.initState();
    _walletName = widget.walletName;
    _selectedCard = widget.cardBackground;
  }

  String _truncate(String addr) {
    if (addr.length <= 8) return addr;
    return '${addr.substring(0, 4)}...${addr.substring(addr.length - 4)}';
  }

  void _showWalletOptions() {
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
            // Drag handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
            ),

            _optionRow(Icons.copy, 'Copy address', () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: widget.walletAddress));
              showCopiedToast(context);
            }),

            _optionRow(Icons.edit, 'Rename wallet', () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RenameWalletScreen(currentName: _walletName),
                ),
              ).then((newName) async {
                if (newName != null && newName is String) {
                  setState(() => _walletName = newName);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('wallet_name', newName);
                }
              });
            }),

            _optionRow(Icons.brush, 'Edit background', () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditBackgroundScreen(currentCard: _selectedCard),
                ),
              ).then((card) async {
                if (card != null && card is String) {
                  setState(() => _selectedCard = card);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('card_background', card);
                }
              });
            }),

            _optionRow(Icons.description_outlined, 'Export private key', () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExportPrivateKeyScreen()),
              );
            }),

            _optionRow(Icons.description_outlined, 'Export recovery phrase', () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ExportRecoveryScreen()),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _optionRow(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w400)),
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
                      child: Text('My wallets', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text('Edit', style: TextStyle(color: Colors.yellow, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // NET WORTH
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NET WORTH', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '\$${widget.balanceUsd.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${widget.priceChange24h >= 0 ? '+' : ''}${widget.priceChange24h.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: widget.priceChange24h >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                          fontSize: 12,
                          fontFamily: 'FKGroteskSemiMono',
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.tune, color: Colors.grey[500], size: 20),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // RECOVERY PHRASE section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('RECOVERY PHRASE', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500, letterSpacing: 1)),
            ),
            const SizedBox(height: 10),

            // Wallet card — tap to go home, long press for options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                onLongPress: _showWalletOptions,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1F26),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // MW avatar
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(color: Colors.grey[700], shape: BoxShape.circle),
                        child: const Center(
                          child: Text('MW', style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Name + address
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_walletName, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(_truncate(widget.walletAddress), style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk')),
                          ],
                        ),
                      ),

                      // Balance
                      Text(
                        '\$${widget.balanceUsd.toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500),
                      ),
                    ],
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
