import 'dart:async';

import 'package:flutter/services.dart';

/// Clipboard helpers for sensitive payloads (private keys, mnemonics).
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
