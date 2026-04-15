import 'dart:async';

import 'package:flutter/services.dart';

/// Clipboard helpers for sensitive payloads (private keys, mnemonics).
///
/// Copies the value, then schedules a best-effort clear after [ttl]. Clearing
/// only overwrites if the clipboard still holds the same value — so if the
/// user has copied something else in the meantime we leave it alone.
class SecureClipboard {
  static const Duration ttl = Duration(seconds: 30);

  static Future<void> copySensitive(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    Timer(ttl, () async {
      try {
        final current = await Clipboard.getData(Clipboard.kTextPlain);
        if (current?.text == value) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {
        // Clipboard unavailable — best effort only.
      }
    });
  }
}
