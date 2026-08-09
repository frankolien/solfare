import 'package:flutter/material.dart';
import 'package:solfare/features/explore/presentation/screens/dapp_browser_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/receive_screen.dart';

/// The two ways money gets into the wallet from outside it.
///
/// Receiving is ours. Bridging is not — Solfare has no bridge integration, so
/// that row opens Wormhole's own front end in the in-app browser rather than
/// pretending to a capability the wallet does not have.
class AddFundsSheet extends StatelessWidget {
  final String walletAddress;

  const AddFundsSheet({super.key, required this.walletAddress});

  /// Wormhole's Portal. `jup.ag/bridge` is a 404; this answers.
  static const bridgeUrl = 'https://portalbridge.com/';

  static Future<void> show(BuildContext context, {required String walletAddress}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AddFundsSheet(walletAddress: walletAddress),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _option(
            icon: Icons.qr_code_2,
            title: 'Receive crypto',
            detail: 'Transfer from an exchange or wallet',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReceiveScreen(walletAddress: walletAddress),
                ),
              );
            },
          ),
          _option(
            icon: Icons.swap_horiz_rounded,
            title: 'Bridge',
            detail: 'Deposit tokens from any chain to Solana',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DappBrowserScreen(
                    initialUrl: bridgeUrl,
                    title: 'Portal Bridge',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _option({
    required IconData icon,
    required String title,
    required String detail,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF23262B),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontFamily: 'FKGrotesk',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
