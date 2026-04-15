import 'package:flutter/foundation.dart';

/// Debug-only logger. In release builds these calls compile to no-ops so
/// sensitive payloads (tx signatures, error traces) never reach `adb logcat`
/// or crash reports.
void debugLog(Object? message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(message);
  }
}
