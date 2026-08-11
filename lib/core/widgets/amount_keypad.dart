import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The in-app number pad for entering an amount.
///
/// Lifted from the send screen rather than reinvented, so the two agree on key
/// size and type. The system keyboard is wrong here for two reasons: it hides
/// the figure being typed behind itself, and it offers a layout with letters
/// on it for a field that only takes digits.
class AmountKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  /// Held down to clear, where the screen supports it.
  final VoidCallback? onDeleteAll;

  const AmountKeypad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int row = 0; row < 3; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int col = 0; col < 3; col++) _key('${row * 3 + col + 1}'),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _key('.'),
              _key('0'),
              GestureDetector(
                // Without this the tap area is the glyph, not the key: a bare
                // SizedBox paints nothing, so deferToChild hit-tests the Text
                // and a finger landing beside the digit hits the background.
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onDelete();
                },
                onLongPress: onDeleteAll == null
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        onDeleteAll!();
                      },
                child: const SizedBox(
                  width: 76,
                  height: 56,
                  child: Center(
                    child: Icon(Icons.backspace_outlined,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _key(String digit) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onDigit(digit);
      },
      child: SizedBox(
        width: 76,
        height: 56,
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'FKGroteskSemiMono',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Appends [digit] to [current] the way a calculator would.
///
/// Shared so the rules — one decimal point, no leading zeros, a bounded
/// fraction — are the same wherever an amount is typed.
String appendDigit(String current, String digit, {int maxDecimals = 9}) {
  if (digit == '.') {
    if (current.contains('.')) return current;
    return current.isEmpty ? '0.' : '$current.';
  }

  final dot = current.indexOf('.');
  if (dot != -1 && current.length - dot - 1 >= maxDecimals) return current;

  // "0" then "5" is 5, not 05 — but "0." then "5" is 0.5.
  if (current == '0') return digit;
  return current + digit;
}

/// Removes the last character, returning empty rather than a lone sign or dot.
String removeDigit(String current) {
  if (current.isEmpty) return current;
  final next = current.substring(0, current.length - 1);
  return next == '0' ? '' : next;
}
