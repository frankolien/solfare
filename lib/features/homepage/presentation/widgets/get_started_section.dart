import 'package:flutter/material.dart';
import 'package:solfare/l10n/app_localizations.dart';

/// Empty wallet state — prompts user to request test SOL or buy SOL.
class GetStartedSection extends StatelessWidget {
  final String? walletAddress;
  final VoidCallback? onRequestAirdrop;

  const GetStartedSection({
    super.key,
    this.walletAddress,
    this.onRequestAirdrop,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Image.asset('assets/assets/images/empty_wallet.png'),
          const SizedBox(height: 24),
          Text(
            l.getStartedWithSol,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            walletAddress != null ? l.getStartedDescMainnet : l.getStartedDescMainnet,
            style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: walletAddress != null ? onRequestAirdrop : null,
            child: Text(
              walletAddress != null ? l.buySol : l.requestTestSol,
              style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
