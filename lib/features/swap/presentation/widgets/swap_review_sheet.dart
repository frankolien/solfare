import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_bloc.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_event.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_state.dart';
import 'package:solfare/features/wallet/presentation/widgets/tx_preview_body.dart';

/// What the swap actually does, before it is sent.
///
/// The body is the same one every other approval in the app uses, so a route
/// from Jupiter is read the same way as a payment request or a dapp asking
/// for a signature — from the network's own simulation, not from whoever
/// proposed it.
class SwapReviewSheet extends StatelessWidget {
  final SwapReviewing state;

  const SwapReviewSheet({super.key, required this.state});

  static Future<void> show(BuildContext context, SwapReviewing state) {
    final bloc = context.read<SwapBloc>();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: SwapReviewSheet(state: state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = state.preview;
    final blocked = preview.blocked;
    final danger = preview.hasDanger;
    final ready = state.ready;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 12),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 18),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              '${ready.inputAmount} ${ready.inputToken.symbol} '
              '→ ${ready.outputAmount ?? ''} ${ready.outputToken.symbol}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'FKGroteskSemiMono',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TxPreviewBody(preview: preview),
            if (!blocked)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          danger ? const Color(0xFFE03131) : const Color(0xFFF4D03F),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.read<SwapBloc>().add(const ConfirmSwapEvent());
                    },
                    child: Text(
                      danger ? 'Swap anyway' : 'Swap',
                      style: TextStyle(
                        color: danger ? Colors.white : Colors.black,
                        fontSize: 13,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<SwapBloc>().add(const CancelSwapReviewEvent());
              },
              child: Text(
                blocked ? 'Back' : 'Cancel',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontFamily: 'FKGrotesk',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
