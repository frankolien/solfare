import 'package:flutter/material.dart';
import 'package:solfare/core/currency/money.dart';

/// One half of the swap: the figure large on the left, the token on the right,
/// and what each is worth underneath.
///
/// Its height is part of the screen's layout budget — see `SwapLayout` — so
/// it lives on its own where a test can measure it.
class AmountCard extends StatelessWidget {
  final String label;
  final String amount;

  /// Nothing entered yet, so the figure is a placeholder rather than a value.
  final bool dimmed;

  final double? valueUsd;
  final Widget trailing;
  final String balance;
  final Widget? labelSuffix;

  /// Waiting on a quote, which replaces the figure rather than the whole card.
  final bool loading;

  const AmountCard({
    super.key,
    required this.label,
    required this.amount,
    required this.dimmed,
    required this.valueUsd,
    required this.trailing,
    required this.balance,
    this.labelSuffix,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1)),
              if (labelSuffix != null) ...[
                const SizedBox(width: 4),
                labelSuffix!,
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: loading
                    ? SizedBox(
                        height: 32,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: Colors.grey[500]),
                          ),
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          amount,
                          style: TextStyle(
                            color: dimmed ? Colors.grey[700] : Colors.white,
                            fontSize: 32,
                            fontFamily: 'FKGroteskSemiMono',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                valueUsd == null ? '' : Money.format(valueUsd!),
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontFamily: 'FKGroteskSemiMono'),
              ),
              const Spacer(),
              Text(balance,
                  style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontFamily: 'FKGrotesk')),
            ],
          ),
        ],
      ),
    );
  }
}
