import 'package:flutter/material.dart';
import 'package:solfare/l10n/app_localizations.dart';

/// Homepage action buttons row (Deposit, Swap, Stake, Send).
class ActionButtons extends StatelessWidget {
  final VoidCallback? onSend;
  final VoidCallback? onDeposit;
  final VoidCallback? onStake;

  const ActionButtons({super.key, this.onSend, this.onDeposit, this.onStake});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final actions = [
      _Action(icon: Icons.arrow_downward, label: l.deposit, onTap: onDeposit ?? () {}),
      _Action(icon: Icons.swap_horiz, label: l.swap, onTap: () {}),
      _Action(icon: Icons.savings, label: l.stake, onTap: onStake ?? () {}),
      _Action(icon: Icons.send, label: l.send, onTap: onSend ?? () {}),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((action) {
          return GestureDetector(
            onTap: action.onTap,
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFF23262B),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Action {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Action({required this.icon, required this.label, required this.onTap});
}
