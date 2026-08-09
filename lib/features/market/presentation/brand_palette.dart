import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Reads a token's brand colour out of its logo.
///
/// A pure function of pixel bytes, so it is tested against buffers rather
/// than against the network.
class BrandPalette {
  const BrandPalette._();

  /// A pixel you can barely see has no colour to give.
  static const int minAlpha = 128;

  /// Below this there is no hue, only a shade — the white plate, the drop
  /// shadow, the grey wordmark.
  static const double minSaturation = 0.25;

  /// The floor excludes the near-black disc a great many logos sit on. At
  /// 0.10 that disc gets back in and wins with its own faint tint.
  static const double minLightness = 0.18;
  static const double maxLightness = 0.92;

  /// 15° apiece.
  static const int hueBuckets = 24;

  /// Share of the visible centre that has to carry a hue before there is a
  /// brand colour to speak of. Below it the logo is greyscale and the caller
  /// keeps whatever colour it was already using.
  static const double minCoverage = 0.06;

  /// A logo's identity is what sits in the middle of it. Sampling the whole
  /// image lets a corner badge — a wrapped-asset marker, say — outvote a mark
  /// that has no hue of its own.
  static const double centreRadius = 0.62;

  /// What a line needs to read against a near-black background.
  static const double readableLightness = 0.55;

  /// Roughly how many samples to take across the image, whatever its size.
  static const int sampleSpan = 48;

  /// Null when the logo has no brand colour: greyscale, invisible, or too
  /// small to sample. Null is an answer, not a failure — inventing a hue out
  /// of four anti-aliased pixels would look deliberate and mean nothing.
  static Color? fromPixels(
    Uint8List rgba, {
    required int width,
    required int height,
  }) {
    if (width <= 0 || height <= 0) return null;
    if (rgba.length < width * height * 4) return null;

    final stride = math.max(1, math.min(width, height) ~/ sampleSpan);
    final centreX = width / 2;
    final centreY = height / 2;
    final radius = math.min(width, height) / 2 * centreRadius;

    final weights = List<double>.filled(hueBuckets, 0);
    final hues = List<double>.filled(hueBuckets, 0);
    final saturations = List<double>.filled(hueBuckets, 0);
    final lightnesses = List<double>.filled(hueBuckets, 0);

    var visible = 0;
    var coloured = 0;

    for (var y = 0; y < height; y += stride) {
      for (var x = 0; x < width; x += stride) {
        final dx = x + 0.5 - centreX;
        final dy = y + 0.5 - centreY;
        if (dx * dx + dy * dy > radius * radius) continue;

        final i = (y * width + x) * 4;
        if (rgba[i + 3] < minAlpha) continue;
        visible++;

        final hsl = _toHsl(rgba[i], rgba[i + 1], rgba[i + 2]);
        final h = hsl.$1;
        final s = hsl.$2;
        final l = hsl.$3;
        if (s < minSaturation || l < minLightness || l > maxLightness) continue;
        coloured++;

        // A vivid mid-tone beats a pale or a muddy one of the same hue.
        final weight = s * (1 - (l - 0.5).abs() * 1.2);
        final bucket = (h * hueBuckets).floor() % hueBuckets;
        weights[bucket] += weight;
        hues[bucket] += h * weight;
        saturations[bucket] += s * weight;
        lightnesses[bucket] += l * weight;
      }
    }

    if (visible == 0 || coloured / visible < minCoverage) return null;

    var best = 0;
    for (var i = 1; i < hueBuckets; i++) {
      if (weights[i] > weights[best]) best = i;
    }
    final total = weights[best];
    if (total <= 0) return null;

    // Lightness is lifted for legibility. Saturation is not: raising it would
    // turn a barely-tinted pixel into a vivid claim about the brand.
    return _fromHsl(
      hues[best] / total,
      saturations[best] / total,
      math.max(lightnesses[best] / total, readableLightness),
    );
  }

  /// Hue, saturation and lightness, each 0..1.
  static (double, double, double) _toHsl(int r8, int g8, int b8) {
    final r = r8 / 255;
    final g = g8 / 255;
    final b = b8 / 255;
    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    final l = (max + min) / 2;

    if (max == min) return (0, 0, l);

    final d = max - min;
    final s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    final double h;
    if (max == r) {
      h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
    } else if (max == g) {
      h = ((b - r) / d + 2) / 6;
    } else {
      h = ((r - g) / d + 4) / 6;
    }
    return (h, s, l);
  }

  static Color _fromHsl(double h, double s, double l) {
    if (s == 0) {
      final v = (l * 255).round().clamp(0, 255);
      return Color.fromARGB(255, v, v, v);
    }
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    int channel(double t) {
      var x = t;
      if (x < 0) x += 1;
      if (x > 1) x -= 1;
      final double v;
      if (x < 1 / 6) {
        v = p + (q - p) * 6 * x;
      } else if (x < 1 / 2) {
        v = q;
      } else if (x < 2 / 3) {
        v = p + (q - p) * (2 / 3 - x) * 6;
      } else {
        v = p;
      }
      return (v * 255).round().clamp(0, 255);
    }

    return Color.fromARGB(255, channel(h + 1 / 3), channel(h), channel(h - 1 / 3));
  }
}
