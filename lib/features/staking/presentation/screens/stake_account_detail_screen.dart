import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:solfare/features/staking/domain/entities/stake_account.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_bloc.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_event.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_state.dart';

class StakeAccountDetailScreen extends StatelessWidget {
  final StakeAccount account;
  final double solPriceUsd;

  const StakeAccountDetailScreen({
    super.key,
    required this.account,
    required this.solPriceUsd,
  });

  double get _usdValue => account.amountInSol * solPriceUsd;

  Color _statusColor(String state) {
    switch (state) {
      case 'active':
        return const Color(0xFF4CAF50);
      case 'activating':
        return const Color(0xFF7C7CFF);
      case 'deactivating':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String state) {
    switch (state) {
      case 'active':
        return 'Active';
      case 'activating':
        return 'Activating';
      case 'deactivating':
        return 'Deactivating';
      default:
        return 'Inactive';
    }
  }

  void _onMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'unstake':
        _showUnstakeConfirm(context);
      case 'explorer':
        _openExplorer();
    }
  }

  void _showUnstakeConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unstake', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
        content: Text(
          'This will deactivate your stake of ${account.amountInSol.toStringAsFixed(3)} SOL. After deactivation completes (~1 epoch), you can withdraw your SOL.',
          style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'FKGrotesk', height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (account.state == 'inactive' || account.state == 'deactivating') {
                // Already deactivated — withdraw
                context.read<StakingBloc>().add(WithdrawStakeEvent(
                  stakeAccountPubkey: account.pubkey,
                  lamports: account.lamports,
                ));
              } else {
                // Deactivate first
                context.read<StakingBloc>().add(DeactivateStakeEvent(account.pubkey));
              }
            },
            child: const Text('Unstake', style: TextStyle(color: Colors.red, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _openExplorer() async {
    final url = 'https://explorer.solana.com/address/${account.pubkey}?cluster=devnet';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StakingBloc, StakingState>(
      listener: (context, state) {
        if (state is StakeDeactivated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stake deactivated! Cooling down...'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true); // return true to trigger refresh
        } else if (state is StakeWithdrawn) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOL withdrawn to your wallet!'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        } else if (state is StakingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.message}'), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0a0b12),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text('Account details', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                      color: const Color(0xFF2A2D35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (action) => _onMenuAction(context, action),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'unstake',
                          child: Text('Unstake', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk')),
                        ),
                        const PopupMenuItem(
                          value: 'explorer',
                          child: Text('View on explorer', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Amount + status
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${_usdValue.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${account.amountInSol.toStringAsFixed(3)} SOL',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13, fontFamily: 'FKGroteskSemiMono'),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(account.state).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(account.state),
                        style: TextStyle(
                          color: _statusColor(account.state),
                          fontSize: 12,
                          fontFamily: 'FKGrotesk',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Details tab
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Details', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Container(height: 2, width: 50, color: Colors.yellow),
                  ],
                ),
              ),

              const Divider(color: Colors.white10, height: 20, indent: 0, endIndent: 0),

              // Detail rows
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Validator',
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle),
                            child: const Center(child: Icon(Icons.diamond, color: Colors.orange, size: 14)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            account.voterPubkey != null
                                ? 'Validator ${account.voterPubkey!.substring(0, 4)}...${account.voterPubkey!.substring(account.voterPubkey!.length - 4)}'
                                : 'Unknown',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(
                      'Time to stake',
                      Text(
                        account.state == 'active' ? 'Active' : account.state == 'activating' ? '~6h 38m' : account.state == 'deactivating' ? 'Cooling down' : 'Ready',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(
                      'APY',
                      const Text('~0.00%', style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(
                      'Total staked',
                      Text(
                        '${account.amountInSol.toStringAsFixed(3)} SOL',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, Widget value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk')),
        value,
      ],
    );
  }
}
