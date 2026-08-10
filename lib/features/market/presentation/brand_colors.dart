import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/market/presentation/brand_palette.dart';

/// Brand colours, resolved from logo URLs and remembered.
class BrandColors {
  const BrandColors._();

  static final Map<String, Color?> _cache = {};
  static final Map<String, Future<Color?>> _inFlight = {};

  /// Null when there is no brand colour to be had: no URL, a network error, an
  /// SVG, a decode failure, or a logo with no hue in it.
  static Future<Color?> of(String imageUrl) {
    if (imageUrl.isEmpty) return Future.value(null);
    if (_cache.containsKey(imageUrl)) return Future.value(_cache[imageUrl]);
    return _inFlight[imageUrl] ??= _load(imageUrl).whenComplete(() {
      _inFlight.remove(imageUrl);
    });
  }

  /// The answer if it is already known, without waiting.
  static Color? cached(String imageUrl) => _cache[imageUrl];

  static Future<Color?> _load(String url) async {
    try {
      final image = await _decode(NetworkImage(url));
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) return _remember(url, null);

      return _remember(
        url,
        BrandPalette.fromPixels(
          data.buffer.asUint8List(),
          width: image.width,
          height: image.height,
        ),
      );
    } catch (e) {
      // An icon that will not load is not worth a second attempt on every
      // rebuild, so the failure is remembered too.
      debugLog('[Brand] $url: $e');
      return _remember(url, null);
    }
  }

  static Color? _remember(String url, Color? color) {
    _cache[url] = color;
    return color;
  }

  static Future<ui.Image> _decode(ImageProvider provider) {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(info.image);
      },
      onError: (error, stack) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    );

    stream.addListener(listener);
    return completer.future;
  }

  static void resetForTest() {
    _cache.clear();
    _inFlight.clear();
  }
}
