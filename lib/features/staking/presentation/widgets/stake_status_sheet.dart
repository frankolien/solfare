import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

class StakeStatusSheet extends StatelessWidget {
  final String status; // 'staking', 'success', 'error'
  final String? signature;
  final String? error;
  final VoidCallback onClose;

  const StakeStatusSheet({
    super.key,
    required this.status,
    this.signature,
    this.error,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 12),
              child: status != 'staking'
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: onClose,
                    )
                  : const SizedBox(height: 48),
            ),
          ),
          const SizedBox(height: 8),

          // Lottie animation
          SizedBox(
            width: 100, height: 100,
            child: status == 'staking'
                ? Lottie.asset('assets/assets/lottie/stake_loop.json', repeat: true)
                : status == 'success'
                    ? Lottie.asset('assets/assets/lottie/result_success.json', repeat: false)
                    : Lottie.asset('assets/assets/lottie/result_error.json', repeat: false),
          ),
          const SizedBox(height: 16),

          // Status text
          Text(
            status == 'staking' ? 'Staking' : status == 'success' ? 'Success' : 'Failed',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'FKGrotesk', fontWeight: FontWeight.bold),
          ),

          if (status == 'staking')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('You can safely close this screen', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk')),
            ),

          if (status == 'error' && error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(error!, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGrotesk'), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
            ),

          if (status == 'success' && signature != null) ...[
            const SizedBox(height: 24),
            _buildActionRow(context, 'Transaction ID', Icons.copy, () {
              Clipboard.setData(ClipboardData(text: signature!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transaction ID copied'), backgroundColor: Color(0xFF1C1F26), duration: Duration(seconds: 2)),
              );
            }),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
            const SizedBox(height: 12),
            _buildActionRow(context, 'Explorer', Icons.open_in_new, () async {
              final url = 'https://explorer.solana.com/tx/$signature?cluster=devnet';
              try {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              } catch (_) {
                if (context.mounted) Clipboard.setData(ClipboardData(text: url));
              }
            }),
            const SizedBox(height: 20),

            // Close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2D35),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: onClose,
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk')),
            const Spacer(),
            Icon(icon, color: Colors.grey[500], size: 16),
          ],
        ),
      ),
    );
  }
}
