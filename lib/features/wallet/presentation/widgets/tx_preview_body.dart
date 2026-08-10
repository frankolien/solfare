import 'package:solfare/core/solana/lamports.dart';
import 'package:flutter/material.dart';
import 'package:solfare/core/solana/preview/tx_preview.dart';

/// The part of an approval sheet that is the same everywhere: what the
/// transaction moves, what is worth worrying about, and what it costs.
///
/// Send, Solana Pay and dApp requests each supply their own header and then
/// show this. One body means one place to get the safety wording right.
class TxPreviewBody extends StatelessWidget {
  /// Null while the simulation is still running.
  final TxPreview? preview;

  const TxPreviewBody({super.key, required this.preview});

  static const _cardColor = Color(0xFF1C1F26);
  static const _danger = Color(0xFFE03131);
  static const _caution = Color(0xFFF08C00);

  @override
  Widget build(BuildContext context) {
    final p = preview;
    if (p == null) return const _PreviewSkeleton();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.blocked) _blocked(p.failureReason),
        if (p.unverified) _unverified(p.failureReason),
        if (p.willFail) _willFail(p.failureReason),
        for (final flag in p.flags) _flagTile(flag),
        if (p.ownDeltas.isNotEmpty) _deltas(p.ownDeltas),
        // The decoded steps. These were computed and then never rendered:
        // visibleInstructions had no call sites anywhere in the app, and
        // RiskFlag.instructionIndex was never read either. So an instruction
        // reached the user only if a risk rule happened to fire on it, or it
        // moved a balance on an account whose address equalled the wallet's.
        // A Stake::Withdraw draining a stake account to somebody else clears
        // both of those and used to render as a fee and nothing else.
        if (p.visibleInstructions.isNotEmpty) _steps(p.visibleInstructions),
        _feeRow(p),
      ],
    );
  }

  Widget _steps(List<DecodedInstruction> instructions) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              instructions.length == 1 ? 'What it does' : 'What it does, in order',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final ix in instructions)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ix.summary,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontFamily: 'FKGrotesk',
                        height: 1.45,
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

  Widget _blocked(String? reason) => _banner(
        icon: Icons.block,
        color: _danger,
        title: 'This cannot be sent',
        detail: reason ?? 'This transfer is not possible.',
      );

  Widget _unverified(String? reason) => _banner(
        icon: Icons.help_outline,
        color: _caution,
        title: 'Could not check this transaction',
        detail: reason ?? 'The network did not answer in time. Approving means '
            'you are trusting it unchecked.',
      );

  Widget _willFail(String? reason) => _banner(
        icon: Icons.error_outline,
        color: _danger,
        title: 'This will fail',
        detail: reason ?? 'The network rejected it when simulated.',
      );

  Widget _flagTile(RiskFlag flag) {
    final (color, icon) = switch (flag.severity) {
      RiskSeverity.danger => (_danger, Icons.gpp_maybe_outlined),
      RiskSeverity.caution => (_caution, Icons.info_outline),
      RiskSeverity.info => (Colors.grey, Icons.info_outline),
    };
    return _banner(icon: icon, color: color, title: flag.title, detail: flag.detail);
  }

  Widget _banner({
    required IconData icon,
    required Color color,
    required String title,
    required String detail,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(detail,
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 11, fontFamily: 'FKGrotesk', height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _deltas(List<BalanceDelta> deltas) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Balance changes',
              style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGrotesk')),
          const SizedBox(height: 8),
          for (final d in deltas) _deltaRow(d),
        ],
      ),
    );
  }

  Widget _deltaRow(BalanceDelta d) {
    final positive = d.isIncoming;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(d.label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk')),
          const Spacer(),
          Text(
            '${positive ? '+' : ''}${_amount(d)}',
            style: TextStyle(
              color: positive ? const Color(0xFF2F9E44) : Colors.white,
              fontSize: 13,
              fontFamily: 'FKGroteskSemiMono',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Trailing zeros make small amounts unreadable, and rounding hides dust.
  String _amount(BalanceDelta d) {
    final value = d.uiDelta;
    final magnitude = value.abs();
    final digits = magnitude >= 1 ? 4 : (d.decimals > 9 ? 9 : d.decimals);
    var s = value.toStringAsFixed(digits);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    }
    return s;
  }

  Widget _feeRow(TxPreview p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          Text('Network fee',
              style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk')),
          const Spacer(),
          Text(
            p.unverified || p.blocked ? '—' : '${_sol(p.feeLamports)} SOL',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'FKGroteskSemiMono',
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _sol(int lamports) {
    var s = Lamports.toSol(lamports).toStringAsFixed(9).replaceFirst(RegExp(r'0+$'), '');
    return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  }
}

/// Shown while the simulation runs. The sheet opens straight away so a slow
/// RPC never leaves the user staring at a spinner with nothing to read.
class _PreviewSkeleton extends StatefulWidget {
  const _PreviewSkeleton();

  @override
  State<_PreviewSkeleton> createState() => _PreviewSkeletonState();
}

class _PreviewSkeletonState extends State<_PreviewSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Checking what this does…',
              style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGrotesk')),
          const SizedBox(height: 10),
          FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 0.7).animate(_pulse),
            child: Column(
              children: [
                _bar(width: double.infinity, height: 44),
                const SizedBox(height: 8),
                _bar(width: double.infinity, height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar({required double width, required double height}) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26),
          borderRadius: BorderRadius.circular(10),
        ),
      );
}
