import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/features/staking/domain/entities/validator_info.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_bloc.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_event.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_state.dart';

class ValidatorPickerSheet extends StatefulWidget {
  final ValidatorInfo currentValidator;
  final ValueChanged<ValidatorInfo> onSelected;

  const ValidatorPickerSheet({
    super.key,
    required this.currentValidator,
    required this.onSelected,
  });

  @override
  State<ValidatorPickerSheet> createState() => _ValidatorPickerSheetState();
}

class _ValidatorPickerSheetState extends State<ValidatorPickerSheet> {
  @override
  void initState() {
    super.initState();
    context.read<StakingBloc>().add(const FetchValidatorsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle + header
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Select validator', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),

          // Validator list
          Expanded(
            child: BlocBuilder<StakingBloc, StakingState>(
              builder: (context, state) {
                if (state is StakingLoading) {
                  return const Center(child: CircularProgressIndicator(color: Colors.yellow, strokeWidth: 2));
                }
                if (state is ValidatorsFetched) {
                  final validators = state.validators;
                  if (validators.isEmpty) {
                    return Center(
                      child: Text('No validators found', style: TextStyle(color: Colors.grey[500], fontSize: 13, fontFamily: 'FKGrotesk')),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: validators.length,
                    itemBuilder: (context, index) {
                      final v = validators[index];
                      final isSelected = v.votePubkey == widget.currentValidator.votePubkey;
                      return GestureDetector(
                        onTap: () {
                          widget.onSelected(v);
                          Navigator.pop(context);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle),
                                child: const Center(child: Icon(Icons.diamond, color: Colors.orange, size: 18)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(v.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Stake: ${_formatStake(v.totalStakeInSol)} SOL  |  ${v.commission.toStringAsFixed(0)}% commission',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGroteskSemiMono'),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check, color: Colors.yellow, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
                if (state is StakingError) {
                  return Center(
                    child: Text('Error: ${state.message}', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk'), textAlign: TextAlign.center),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatStake(double sol) {
    if (sol >= 1000000) return '${(sol / 1000000).toStringAsFixed(1)}M';
    if (sol >= 1000) return '${(sol / 1000).toStringAsFixed(1)}K';
    return sol.toStringAsFixed(0);
  }
}
