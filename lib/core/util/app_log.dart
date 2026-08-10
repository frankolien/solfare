import 'package:flutter/foundation.dart';

/// Debug-only logger.
void debugLog(Object? message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(message);
  }
}
