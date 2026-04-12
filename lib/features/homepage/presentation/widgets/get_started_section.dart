import 'package:flutter/material.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Image.asset('assets/assets/images/empty_wallet.png'),
          const SizedBox(height: 24),
          const Text(
            'Get Started With SOL',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            walletAddress != null
                ? 'Request free test SOL on devnet to start trading, staking, and exploring. You\'ll need a tiny amount of SOL for each Solana transaction.'
                : 'Buy SOL to start trading, staking, and exploring. You\'ll need a tiny amount of SOL for each Solana transaction.',
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
              walletAddress != null ? 'Request Test SOL' : 'Buy SOL',
              style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
