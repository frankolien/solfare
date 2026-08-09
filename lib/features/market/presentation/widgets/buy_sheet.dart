import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/presentation/bloc/buy_bloc.dart';
import 'package:solfare/features/market/presentation/bloc/buy_event.dart';
import 'package:solfare/features/market/presentation/bloc/buy_state.dart';
import 'package:solfare/features/market/presentation/market_format.dart';
import 'package:solfare/features/market/presentation/widgets/market_token_icon.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';
import 'package:solfare/features/wallet/presentation/widgets/tx_preview_body.dart';

/// Buys an asset with SOL or USDC.
///
/// Two stages in one sheet: pick an amount, then approve what the simulation
/// says the route will actually do. The second stage is the same body every
/// other approval in the app uses, so the safety wording has one home.
class BuySheet extends StatefulWidget {
  final MarketToken asset;
  final String walletAddress;

  const BuySheet({super.key, required this.asset, required this.walletAddress});

  /// Opens the sheet and returns the signature when a purchase landed.
  static Future<String?> show(
    BuildContext context, {
    required MarketToken asset,
    required String walletAddress,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider(
        create: (_) => BuyBloc()
          ..add(BuyStarted(asset: asset, walletAddress: walletAddress)),
        child: BuySheet(asset: asset, walletAddress: walletAddress),
      ),
    );
  }

  @override
  State<BuySheet> createState() => _BuySheetState();
}

class _BuySheetState extends State<BuySheet> {
  final TextEditingController _amountController = TextEditingController();

  MarketToken get asset => widget.asset;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  static const _background = Color(0xFF141518);
  static const _card = Color(0xFF1C1F26);
  static const _accent = Color(0xFF7BD64B);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BuyBloc, BuyState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (context, state) {
        if (state.status == BuyStatus.done) {
          Navigator.of(context).pop(state.signature);
        }
      },
      builder: (context, state) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _handle(),
                _header(),
                const SizedBox(height: 14),
                if (state.status == BuyStatus.review ||
                    state.status == BuyStatus.sending ||
                    state.status == BuyStatus.failed)
                  ..._reviewStage(context, state)
                else
                  ..._amountStage(context, state),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _handle() => Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _header() {
    return Column(
      children: [
        MarketTokenIcon(token: asset, size: 44),
        const SizedBox(height: 10),
        Text(
          'Buy ${asset.symbol.isNotEmpty ? asset.symbol : MarketFormat.shortMint(asset.id)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontFamily: 'FKGrotesk',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          MarketFormat.price(asset.currentPrice),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 12,
            fontFamily: 'FKGroteskSemiMono',
          ),
        ),
      ],
    );
  }

  // ── Stage one: how much ──────────────────────────────────────────────

  List<Widget> _amountStage(BuildContext context, BuyState state) {
    return [
      _payWithToggle(context, state),
      const SizedBox(height: 18),
      _amountField(context, state),
      const SizedBox(height: 10),
      _balanceLine(state),
      const SizedBox(height: 14),
      _presets(context, state),
      const SizedBox(height: 16),
      _receiveLine(state),
      if (state.error != null) _errorLine(state.error!),
      const SizedBox(height: 12),
      _reviewButton(context, state),
    ];
  }

  Widget _payWithToggle(BuildContext context, BuyState state) {
    const options = [SwapToken.sol, SwapToken.usdc];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(22)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            GestureDetector(
              onTap: () => context.read<BuyBloc>().add(BuyPayWithChanged(option)),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: option.mint == state.payWith.mint
                      ? const Color(0xFF2A2D35)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  option.symbol,
                  style: TextStyle(
                    color: option.mint == state.payWith.mint ? Colors.white : Colors.grey[600],
                    fontSize: 12,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _amountField(BuildContext context, BuyState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: TextField(
        controller: _controllerFor(state),
        autofocus: false,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
        style: const TextStyle(
          color: Colors.white,
          fontSize: 38,
          fontFamily: 'FKGroteskSemiMono',
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: TextStyle(
            color: Colors.grey[700],
            fontSize: 38,
            fontFamily: 'FKGroteskSemiMono',
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (value) => context.read<BuyBloc>().add(BuyAmountChanged(value)),
      ),
    );
  }

  /// Kept in step with the state so a preset can set the field without the
  /// field overwriting it again on the next rebuild.
  TextEditingController _controllerFor(BuyState state) {
    if (_amountController.text != state.amountText) {
      _amountController.value = TextEditingValue(
        text: state.amountText,
        selection: TextSelection.collapsed(offset: state.amountText.length),
      );
    }
    return _amountController;
  }

  Widget _balanceLine(BuyState state) {
    final balance = state.balance;
    return Text(
      balance == null
          ? 'Checking balance…'
          : '${_trim(balance)} ${state.payWith.symbol} available',
      style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGroteskSemiMono'),
    );
  }

  Widget _presets(BuildContext context, BuyState state) {
    final presets = state.payWith.mint == SwapToken.sol.mint
        ? const ['0.1', '0.25', '0.5']
        : const ['10', '50', '100'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final preset in presets) ...[
            Expanded(child: _presetChip(context, preset, preset == state.amountText)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: _presetChip(
              context,
              'Max',
              false,
              value: state.balance == null ? null : _trim(state.spendable),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(BuildContext context, String label, bool selected, {String? value}) {
    final amount = value ?? label;
    final enabled = value != '0';
    return GestureDetector(
      onTap: enabled ? () => context.read<BuyBloc>().add(BuyAmountChanged(amount)) : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2A2D35) : _card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontFamily: 'FKGroteskSemiMono',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _receiveLine(BuyState state) {
    final receive = state.receiveAmount;
    final text = state.isQuoting
        ? 'Finding the best route…'
        : receive == null
            ? 'You receive ${asset.symbol}'
            : 'You receive about ${_trim(receive)} ${asset.symbol}';
    return Text(
      text,
      style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk'),
    );
  }

  Widget _errorLine(String error) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Text(
        error,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFE03131),
          fontSize: 12,
          fontFamily: 'FKGrotesk',
        ),
      ),
    );
  }

  Widget _reviewButton(BuildContext context, BuyState state) {
    final preparing = state.status == BuyStatus.preparing;
    final blocked = !state.hasEnough;
    final enabled = state.canReview && !preparing;

    final label = blocked
        ? 'Insufficient balance'
        : preparing
            ? 'Checking…'
            : 'Review purchase';

    return _primaryButton(
      label: label,
      enabled: enabled,
      onPressed: () => context.read<BuyBloc>().add(const BuyReviewRequested()),
    );
  }

  // ── Stage two: what it actually does ─────────────────────────────────

  List<Widget> _reviewStage(BuildContext context, BuyState state) {
    if (state.status == BuyStatus.failed) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFE03131), size: 28),
              const SizedBox(height: 12),
              Text(
                state.error ?? 'The purchase did not go through.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontFamily: 'FKGrotesk',
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        _primaryButton(
          label: 'Back',
          enabled: true,
          onPressed: () => context.read<BuyBloc>().add(const BuyReviewDismissed()),
        ),
      ];
    }

    final preview = state.preview;
    final blocked = preview?.blocked ?? false;
    final danger = preview?.hasDanger ?? false;
    final sending = state.status == BuyStatus.sending;

    return [
      TxPreviewBody(preview: preview),
      if (!blocked)
        _primaryButton(
          label: sending ? 'Buying…' : (danger ? 'Buy anyway' : 'Buy'),
          enabled: !sending,
          danger: danger,
          onPressed: () => context.read<BuyBloc>().add(const BuyConfirmed()),
        ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: sending ? null : () => context.read<BuyBloc>().add(const BuyReviewDismissed()),
        child: Text(
          blocked ? 'Back' : 'Cancel',
          style: TextStyle(color: Colors.grey[500], fontSize: 13, fontFamily: 'FKGrotesk'),
        ),
      ),
    ];
  }

  Widget _primaryButton({
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
    bool danger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: !enabled
                ? const Color(0xFF2A2D35)
                : danger
                    ? const Color(0xFFE03131)
                    : _accent,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            elevation: 0,
          ),
          onPressed: enabled ? onPressed : null,
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.black : Colors.grey[600],
              fontSize: 14,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// Balances read better without a tail of zeros, but never rounded to
  /// nothing — a dust balance is still a balance.
  String _trim(double value) {
    var text = value.toStringAsFixed(value.abs() >= 1 ? 4 : 6);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    }
    return text.isEmpty ? '0' : text;
  }
}
