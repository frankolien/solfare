/// The heights the swap screen's fixed layout is budgeted from.
///
/// Each one is measured from the widget it names; `swap_layout_test`
/// re-measures them and fails if one drifts.
class SwapLayout {
  /// An amount card — the SELL and BUY halves are the same shape.
  static const cardHeight = 122.0;

  /// The divider carrying the flip button.
  static const flipHeight = 48.0;

  static const percentRowHeight = 43.0;
  static const buttonHeight = 48.0;

  /// Between the header and the first card.
  static const topGap = 8.0;

  /// Between bands, and between keypad rows.
  static const gap = 8.0;

  /// Between the keypad and the button, which carries more weight than a gap
  /// between keys.
  static const buttonGap = 10.0;

  /// The smallest comfortable target, and the size the keys are drawn at when
  /// there is room for it.
  static const minKeyHeight = 44.0;
  static const maxKeyHeight = 56.0;

  /// Room for the constants below to be a little wrong. Budgeting the cards
  /// their exact height leaves a point of drift nowhere to go but a clipped
  /// edge; with this it shows up as a gap instead.
  static const slack = 8.0;

  /// What the two cards and the flip divider want, with nothing scrolled.
  static const cardsBand =
      topGap + cardHeight + flipHeight + cardHeight + slack;

  /// Everything pinned below the cards apart from the keys themselves.
  static const _inputBandChrome =
      gap + percentRowHeight + gap + (gap * 3) + buttonGap + buttonHeight;

  /// The key height that leaves the cards their full height in [available],
  /// which is the space below the header.
  ///
  /// Bounded below, so a screen too short for both scrolls the cards rather
  /// than shrinking the keys past the point of being tappable.
  static double keyHeight(double available) {
    final forKeys = (available - cardsBand - _inputBandChrome) / 4;
    return forKeys.clamp(minKeyHeight, maxKeyHeight);
  }

  /// The height of the pinned band for a given [keyHeight].
  static double inputBand(double keyHeight) =>
      _inputBandChrome + keyHeight * 4;
}
