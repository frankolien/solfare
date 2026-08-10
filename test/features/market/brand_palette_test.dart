import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/features/market/presentation/brand_palette.dart';

void main() {
  const size = 64;

  /// A blank RGBA buffer, fully transparent.
  Uint8List canvas() => Uint8List(size * size * 4);

  void put(Uint8List px, int x, int y, Color c) {
    final i = (y * size + x) * 4;
    px[i] = (c.r * 255).round();
    px[i + 1] = (c.g * 255).round();
    px[i + 2] = (c.b * 255).round();
    px[i + 3] = (c.a * 255).round();
  }

  /// Fills a disc of [radius] fraction of the half-width, centred.
  void disc(Uint8List px, Color c, {double radius = 1.0}) {
    final r = size / 2 * radius;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = x + 0.5 - size / 2;
        final dy = y + 0.5 - size / 2;
        if (dx * dx + dy * dy <= r * r) put(px, x, y, c);
      }
    }
  }

  void square(Uint8List px, Color c, {required int left, required int top, required int side}) {
    for (var y = top; y < top + side && y < size; y++) {
      for (var x = left; x < left + side && x < size; x++) {
        put(px, x, y, c);
      }
    }
  }

  Color? read(Uint8List px) =>
      BrandPalette.fromPixels(px, width: size, height: size);

  /// Hue in degrees, so a test can say "orange" without asserting an exact RGB.
  double hueOf(Color c) {
    final r = c.r, g = c.g, b = c.b;
    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    if (max == min) return 0;
    final d = max - min;
    if (max == r) return (((g - b) / d + (g < b ? 6 : 0)) / 6) * 360;
    if (max == g) return (((b - r) / d + 2) / 6) * 360;
    return (((r - g) / d + 4) / 6) * 360;
  }

  double lightnessOf(Color c) =>
      (math.max(c.r, math.max(c.g, c.b)) + math.min(c.r, math.min(c.g, c.b))) / 2;

  test('a solid mark gives its own hue back', () {
    final px = canvas();
    disc(px, const Color(0xFF1E64FF)); // cbBTC blue
    final brand = read(px)!;
    expect(hueOf(brand), closeTo(220, 12));
  });

  test('a greyscale logo has no brand colour', () {
    // SPYx is a charcoal wordmark. Measured: zero coloured pixels.
    final px = canvas();
    disc(px, const Color(0xFF2A2E2E));
    expect(read(px), isNull,
        reason: 'a hue invented from nothing would look deliberate');
  });

  test('the plate a logo sits on does not win', () {
    // JUP and PUMP both sit on a near-black navy that outnumbers the mark.
    final px = canvas();
    disc(px, const Color(0xFF000020));
    disc(px, const Color(0xFF40C080), radius: 0.35); // the green mark
    final brand = read(px)!;
    expect(hueOf(brand), closeTo(145, 20), reason: 'the mark, not the plate');
  });

  test('a white plate does not win either', () {
    final px = canvas();
    disc(px, const Color(0xFFF2F2F2));
    disc(px, const Color(0xFFD84941), radius: 0.35); // TRON red
    expect(hueOf(read(px)!), closeTo(3, 15));
  });

  test('a corner badge does not outvote a mark with no hue', () {
    // Portal-wrapped ETH: a grey diamond with a magenta Wormhole badge in the
    // bottom-right. Read whole, the badge wins and the chart turns pink.
    final px = canvas();
    disc(px, const Color(0xFFE0E0E0));
    square(px, const Color(0xFFC8006E), left: 44, top: 44, side: 14);
    expect(read(px), isNull,
        reason: 'the badge is not the asset, and the diamond has no hue');
  });

  test('but a badge on a coloured mark leaves the mark alone', () {
    final px = canvas();
    disc(px, const Color(0xFF1E64FF));
    square(px, const Color(0xFFC8006E), left: 44, top: 44, side: 14);
    expect(hueOf(read(px)!), closeTo(220, 12));
  });

  test('transparent pixels are not counted at all', () {
    // The old version of this drew a disc covering 23% of the sampled area
    // and asserted its hue — which holds whether or not transparent pixels
    // are skipped, because black carries no hue and no weight either way.
    //
    // 4% coverage is below minCoverage (6%), so the result depends entirely
    // on the denominator: skip the transparent pixels and the mark is 100%
    // of what was sampled; count them as black and it is 4%, which is not a
    // brand colour. Only one of those returns a hue.
    final px = canvas();
    disc(px, const Color(0xFFFF8A00), radius: 0.13);
    final brand = read(px);
    expect(brand, isNotNull,
        reason: 'transparency is absence, not a black vote');
    expect(hueOf(brand!), closeTo(32, 15));
  });

  test('a nearly invisible mark is not a mark', () {
    final px = canvas();
    disc(px, const Color(0x40FF8A00)); // alpha 64, below the floor
    expect(read(px), isNull);
  });

  double saturationOf(Color c) {
    final max = math.max(c.r, math.max(c.g, c.b));
    final min = math.min(c.r, math.min(c.g, c.b));
    if (max == min) return 0;
    final l = (max + min) / 2;
    return l > 0.5 ? (max - min) / (2 - max - min) : (max - min) / (max + min);
  }

  test('a dark brand colour is lifted enough to read on black', () {
    // 0xFF1F3D7A: lightness 0.30, saturation 0.60 — inside both floors, so
    // it survives the filter and the lift is the only thing under test.
    //
    // This test used to use 0xFF14233F, whose lightness is 0.163 and so
    // falls below minLightness (0.18): every pixel was skipped, fromPixels
    // returned null, and the assertion sat inside `if (brand != null)` and
    // never ran. readableLightness had zero coverage as a result — deleting
    // the math.max that applies it left the suite green.
    final px = canvas();
    disc(px, const Color(0xFF1F3D7A));
    final brand = read(px);
    expect(brand, isNotNull, reason: 'this colour is inside every floor');
    expect(lightnessOf(brand!),
        greaterThanOrEqualTo(BrandPalette.readableLightness - 0.02));
  });

  test('a colour already light enough is not pushed further', () {
    // The lift is a floor, not a normalisation.
    final px = canvas();
    disc(px, const Color(0xFFB3D1FF)); // lightness ~0.85
    final brand = read(px)!;
    expect(lightnessOf(brand), greaterThan(0.7));
  });

  test('saturation is never invented', () {
    // A muted logo must not come back vivid. This is the bug the measurement
    // caught: lifting saturation turned anti-aliasing into pink.
    //
    // 0xFFB87A7A is 30% saturated — just above the 25% floor, so it is
    // actually measured. The old fixture was 0xFFBEB6BA at 5.8%, which the
    // floor rejected outright, so the guard swallowed the assertion.
    final px = canvas();
    disc(px, const Color(0xFFB87A7A));
    final brand = read(px);
    expect(brand, isNotNull);
    expect(saturationOf(brand!), lessThan(0.45),
        reason: 'a muted logo stays muted');
  });

  test('the winning hue is the vivid one, not merely the commonest', () {
    final px = canvas();
    disc(px, const Color(0xFF6B6F58)); // large, muddy olive
    disc(px, const Color(0xFF00E5FF), radius: 0.4); // smaller, vivid cyan
    expect(hueOf(read(px)!), closeTo(187, 20));
  });

  group('degenerate input', () {
    test('an empty image is not a colour', () {
      expect(BrandPalette.fromPixels(Uint8List(0), width: 0, height: 0), isNull);
    });

    test('a buffer shorter than its stated size is refused', () {
      expect(BrandPalette.fromPixels(Uint8List(16), width: 64, height: 64), isNull,
          reason: 'reading past the end would be a crash, not a colour');
    });

    test('a fully transparent image is not a colour', () {
      expect(read(canvas()), isNull);
    });

    test('a one-pixel image answers rather than being skipped', () {
      // This asserts the answer, where the old version asserted only
      // `returnsNormally` — which was true of a function that returned null
      // for every input.
      //
      // What it still cannot do is catch the removal of the math.max(1, ...)
      // on the sample stride: a stride of 0 makes the sampling loop spin
      // synchronously, and the Dart test runner cannot interrupt that, so
      // the suite hangs instead of failing. Verified by mutating the guard
      // out and watching the run stall. The stride floor is defended by
      // being obvious in the source, not by this test.
      final px = Uint8List.fromList([0xFF, 0x00, 0x00, 0xFF]);
      expect(BrandPalette.fromPixels(px, width: 1, height: 1), isNotNull);
    });
  });
}
