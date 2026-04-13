import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/features/staking/domain/entities/validator_info.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_bloc.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_event.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_state.dart';
import 'package:solfare/features/staking/presentation/widgets/confirm_stake_sheet.dart';
import 'package:solfare/features/staking/presentation/widgets/stake_status_sheet.dart';
import 'package:solfare/features/staking/presentation/widgets/validator_picker_sheet.dart';

class StakeSolScreen extends StatefulWidget {
  final String walletAddress;
  final double balanceInSol;
  final double solPriceUsd;

  const StakeSolScreen({
    super.key,
    required this.walletAddress,
    required this.balanceInSol,
    required this.solPriceUsd,
  });

  @override
  State<StakeSolScreen> createState() => _StakeSolScreenState();
}

class _StakeSolScreenState extends State<StakeSolScreen> {
  final TextEditingController _amountController = TextEditingController();

  // Default validator — top devnet validator
  ValidatorInfo _selectedValidator = const ValidatorInfo(
    votePubkey: 'vgcDar2pryHvMgPkKaZfh8pQy4BJxv7SpwUG7zinWjG',
    name: 'Devnet Validator 1',
    apyPercent: 0.0,
    activatedStake: 38705912619352696,
  );

  double get _amountInSol => double.tryParse(_amountController.text) ?? 0.0;
  double get _amountInUsd => _amountInSol * widget.solPriceUsd;
  double get _annualReturn => _amountInSol * (_selectedValidator.apyPercent / 100);

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _showValidatorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ValidatorPickerSheet(
        currentValidator: _selectedValidator,
        onSelected: (validator) {
          setState(() => _selectedValidator = validator);
        },
      ),
    );
  }

  void _showConfirmSheet() {
    if (_amountInSol <= 0 || _amountInSol > widget.balanceInSol) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConfirmStakeSheet(
        amountInSol: _amountInSol,
        amountInUsd: _amountInUsd,
        validator: _selectedValidator,
        onConfirm: () {
          Navigator.of(context).pop();
          _executeStake();
        },
      ),
    );
  }

  void _executeStake() {
    context.read<StakingBloc>().add(DelegateStakeEvent(
          validatorVoteAccount: _selectedValidator.votePubkey,
          amountInSol: _amountInSol,
        ));
  }

  void _showStatusSheet(String status, {String? signature, String? error}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: status != 'staking',
      enableDrag: status != 'staking',
      isScrollControlled: true,
      builder: (sheetContext) => StakeStatusSheet(
        status: status,
        signature: signature,
        error: error,
        onClose: () {
          Navigator.of(sheetContext).pop();
          context.go(AppRoutes.homepage);
        },
      ),
    );
  }

  void _setMax() {
    final max = widget.balanceInSol.toStringAsFixed(9)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    _amountController.text = max.isEmpty ? '0' : max;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StakingBloc, StakingState>(
      listener: (context, state) {
        if (state is StakeDelegating) {
          _showStatusSheet('staking');
        } else if (state is StakeDelegated) {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          _showStatusSheet('success', signature: state.signature);
        } else if (state is StakingError) {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          _showStatusSheet('error', error: state.message);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0a0b12),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildAssetSection(),
              const SizedBox(height: 24),
              _buildValidatorSection(),
              const Divider(color: Colors.white10, height: 32, indent: 20, endIndent: 20),
              _buildInfoRows(),
              const Spacer(),
              _buildStakeButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Stake SOL',
                style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildAssetSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ASSET', style: TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              GestureDetector(
                onTap: _setMax,
                child: Text('Max: ${widget.balanceInSol.toStringAsFixed(3)}', style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'FKGroteskSemiMono')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                  child: ClipOval(
                    child: Image.network(
                      'https://assets.coingecko.com/coins/images/4128/large/solana.png',
                      width: 32, height: 32, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('SOL', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _amountInSol > widget.balanceInSol ? Colors.red : Colors.white,
                      fontSize: 18,
                      fontFamily: 'FKGroteskSemiMono',
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '0',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 18, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w600),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidatorSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('VALIDATOR', style: TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              const SizedBox(width: 6),
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.grey),
                child: Icon(Icons.info_outline, color: Colors.grey[800], size: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle),
                child: const Center(child: Icon(Icons.diamond, color: Colors.orange, size: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedValidator.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('~${_selectedValidator.apyPercent.toStringAsFixed(2)}% APY', style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGroteskSemiMono')),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showValidatorPicker,
                child: const Text('Edit', style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRows() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Text('Annual return', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk')),
              const SizedBox(width: 6),
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.grey),
                child: Icon(Icons.info_outline, color: Colors.grey[800], size: 14),
              ),
              const Spacer(),
              Text(
                '${_annualReturn.toStringAsFixed(8)} SOL',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('Total stake', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk')),
              const SizedBox(width: 6),
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.grey),
                child: Icon(Icons.info_outline, color: Colors.grey[800], size: 14),
              ),
              const Spacer(),
              Text(
                '${_formatStake(_selectedValidator.totalStakeInSol)} SOL',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatStake(double sol) {
    if (sol >= 1000000) return '${(sol / 1000000).toStringAsFixed(1)}M';
    if (sol >= 1000) return '${sol.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    return sol.toStringAsFixed(0);
  }

  Widget _buildStakeButton() {
    final isValid = _amountInSol > 0 && _amountInSol <= widget.balanceInSol;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isValid ? Colors.yellow : const Color(0xFF2A2D35),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 0,
          ),
          onPressed: isValid ? _showConfirmSheet : null,
          child: Text(
            'Stake',
            style: TextStyle(
              color: isValid ? Colors.black : Colors.grey[600],
              fontSize: 14,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
