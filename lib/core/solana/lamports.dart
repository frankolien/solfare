/// Conversions between SOL and lamports.
class Lamports {
  Lamports._();

  static const perSol = 1000000000;

  /// Rounds rather than truncates.
  static int fromSol(double sol) => (sol * perSol).round();

  static double toSol(int lamports) => lamports / perSol;
}
