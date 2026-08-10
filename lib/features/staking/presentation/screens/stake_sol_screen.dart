import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/features/staking/domain/stake_limits.dart';
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

  // No default. The old one was a hardcoded devnet vote account labelled
  // "Devnet Validator 1", carrying a made-up 38.7M SOL stake, while the app
  // defaults to mainnet — so a fresh install's first stake was aimed at an
  // account that does not exist there and failed every time.
  ValidatorInfo? _selectedValidator;

  // Only a delegation this screen started may drive its status sheet.
  // StakingBloc is app-wide: the validator picker and the homepage's stake
  // list both fetch through it, and any error from those used to pop the
  // picker, show a "Failed" sheet for a stake nobody attempted, and send the
  // user home.
  bool _stakeInFlight = false;

  double get _amountInSol => double.tryParse(_amountController.text) ?? 0.0;
  double get _amountInUsd => _amountInSol * widget.solPriceUsd;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
    // So the screen arrives with a real validator for the cluster it is on,
    // rather than needing the user to discover the picker first.
    context.read<StakingBloc>().add(const FetchValidatorsEvent());
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
    final validator = _selectedValidator;
    if (validator == null) return;
    if (!StakeLimits.covers(
      amount: _amountInSol,
      balance: widget.balanceInSol,
    )) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConfirmStakeSheet(
        amountInSol: _amountInSol,
        amountInUsd: _amountInUsd,
        validator: validator,
        onConfirm: () {
          Navigator.of(context).pop();
          _executeStake();
        },
      ),
    );
  }

  void _executeStake() {
    final validator = _selectedValidator;
    if (validator == null) return;
    _stakeInFlight = true;
    context.read<StakingBloc>().add(DelegateStakeEvent(
          validatorVoteAccount: validator.votePubkey,
          amountInSol: _amountInSol,
        ));
  }

  // Tracked by identity: `canPop()` pops whatever is on top, which during a
  // back-press mid-stake is this screen rather than the sheet.
  ModalRoute<void>? _statusRoute;

  void _dismissStatusSheet() {
    final route = _statusRoute;
    _statusRoute = null;
    if (route != null && route.isActive) {
      Navigator.of(context).removeRoute(route);
    }
  }

  void _showStatusSheet(String status, {String? signature, String? error}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: status != 'staking',
      enableDrag: status != 'staking',
      isScrollControlled: true,
      routeSettings: RouteSettings(name: 'stake-status/$status'),
      builder: (sheetContext) {
        _statusRoute = ModalRoute.of(sheetContext) as ModalRoute<void>?;
        return StakeStatusSheet(
          status: status,
          signature: signature,
          error: error,
          onClose: () {
            Navigator.of(sheetContext).pop();
            context.go(AppRoutes.homepage);
          },
        );
      },
    ).whenComplete(() => _statusRoute = null);
  }

  void _setMax() {
    // Not the whole balance. A delegation funds a brand new 200-byte stake
    // account past its rent-exempt minimum on top of the amount staked, and
    // pays two signatures — so "all of it" was an amount that could never
    // land, and every stake within ~0.0023 SOL of the balance failed too.
    final max = StakeLimits.maxStakeable(widget.balanceInSol)
        .toStringAsFixed(9)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
    _amountController.text = max.isEmpty ? '0' : max;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StakingBloc, StakingState>(
      listener: (context, state) {
        // Picking up the first validator for this cluster is the one thing
        // this screen listens for that is not its own delegation.
        if (state is ValidatorsFetched &&
            _selectedValidator == null &&
            state.validators.isNotEmpty) {
          setState(() => _selectedValidator = state.validators.first);
          return;
        }

        if (!_stakeInFlight) return;

        if (state is StakeDelegating) {
          _showStatusSheet('staking');
        } else if (state is StakeDelegated) {
          _stakeInFlight = false;
          _dismissStatusSheet();
          _showStatusSheet('success', signature: state.signature);
        } else if (state is StakingError) {
          _stakeInFlight = false;
          _dismissStatusSheet();
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
                    Text(_selectedValidator?.name ?? 'Choosing a validator…', style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(_validatorSubtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGroteskSemiMono')),
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
          // "Annual return" used to live here, computed from
          // ValidatorInfo.apyPercent — which nothing ever populates, so it
          // always read 0.00000000 SOL. A fabricated zero beside a staking
          // decision is worse than not answering, and commission is a real
          // number we actually fetch.
          Row(
            children: [
              Text('Commission', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk')),
              const Spacer(),
              Text(
                _selectedValidator == null
                    ? '—'
                    : '${_selectedValidator!.commission.toStringAsFixed(0)}%',
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
                _selectedValidator == null
                    ? '—'
                    : '${_formatStake(_selectedValidator!.totalStakeInSol)} SOL',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatStake(double sol) => StakeLimits.formatStake(sol);

  // The commission is real and fetched; the APY is not populated anywhere,
  // so advertising "~0.00% APY" beside a validator was worse than silence.
  String get _validatorSubtitle {
    final validator = _selectedValidator;
    if (validator == null) return 'Loading validators';
    return '${validator.commission.toStringAsFixed(0)}% commission';
  }

  Widget _buildStakeButton() {
    final isValid = _selectedValidator != null &&
        StakeLimits.covers(amount: _amountInSol, balance: widget.balanceInSol);
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
