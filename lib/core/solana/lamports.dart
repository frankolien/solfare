/// Conversions between SOL and lamports.
///
/// The literal `1000000000` appeared at seventeen call sites and the two
/// directions had already drifted apart. wallet_bloc carried the correct
/// rounding and a comment explaining it; staking_bloc, three files away,
/// did the same conversion with `.toInt()` — the truncation that comment
/// warns about. There was nowhere for the fix to propagate to.
class Lamports {
  Lamports._();

  static const perSol = 1000000000;

  /// Rounds rather than truncates.
  ///
  /// Measured, not assumed: `0.000065 * 1e9` is 64999.99999999999 in binary
  /// floating point, so `toInt()` sends 64999 lamports where the user asked
  /// for 65000. (wallet_bloc carried this rule with `0.29` as the example.
  /// That one is exact — 290000000.0 — so the comment was wrong even though
  /// the rule was right. The divergences are all down in the sub-millionth
  /// of a SOL, which is exactly where nobody notices them.)
  static int fromSol(double sol) => (sol * perSol).round();

  static double toSol(int lamports) => lamports / perSol;
}
