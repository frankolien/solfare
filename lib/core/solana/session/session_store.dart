import 'dart:convert';

import 'package:solfare/core/security/secure_store.dart';
import 'package:solfare/core/solana/session/dapp_session.dart';
import 'package:solfare/core/util/app_log.dart';

/// Where dapp sessions live.
///
/// Session private keys sit in the same secure storage as the mnemonic, not
/// in shared preferences: a session key signs nothing by itself, but it
/// decrypts everything a dapp ever sent, including transactions the user was
/// asked to approve.
class SessionStore {
  const SessionStore();

  static const _key = 'dapp_sessions';

  Future<List<DappSession>> all() async {
    try {
      final raw = await SecureStore.instance.read(key: _key);
      if (raw == null || raw.isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return [
        for (final entry in decoded)
          if (entry is Map<String, dynamic>) DappSession.fromJson(entry),
      ];
    } catch (e) {
      // Unreadable storage must not lock the user out of the wallet. Losing
      // sessions costs a reconnect; throwing here would cost the app.
      debugLog('[Session] could not read sessions: $e');
      return const [];
    }
  }

  /// Live sessions only. Expired ones are dropped as they are found, so a
  /// stale session cannot be used just because nobody opened the list.
  Future<List<DappSession>> active({DateTime? now}) async {
    // UTC throughout: sessions are stored in UTC, and comparing them against
    // a local clock is how a nine-hour timezone shift became nine hours of
    // extra session life.
    final clock = (now ?? DateTime.now()).toUtc();
    final sessions = await all();
    final live = sessions.where((s) => !s.isExpiredAt(clock)).toList();
    if (live.length != sessions.length) await _write(live);
    return live;
  }

  /// The session for [dappPublicKey], or null when there is none, it expired,
  /// or it belongs to a wallet the user is no longer using.
  Future<DappSession?> find(String dappPublicKey, {String? walletAddress, DateTime? now}) async {
    for (final session in await active(now: now)) {
      if (session.dappPublicKey != dappPublicKey) continue;
      if (walletAddress != null && session.walletAddress != walletAddress) return null;
      return session;
    }
    return null;
  }

  Future<void> save(DappSession session) async {
    final sessions = await all();
    // One session per dapp key — reconnecting replaces rather than stacks.
    sessions.removeWhere((s) => s.dappPublicKey == session.dappPublicKey);
    sessions.add(session);
    await _write(sessions);
  }

  /// Mark a session as used, which is what keeps it from expiring.
  Future<void> touch(String dappPublicKey, {DateTime? now}) async {
    final sessions = await all();
    final index = sessions.indexWhere((s) => s.dappPublicKey == dappPublicKey);
    if (index == -1) return;
    sessions[index] = sessions[index].touched((now ?? DateTime.now()).toUtc());
    await _write(sessions);
  }

  Future<void> revoke(String dappPublicKey) async {
    final sessions = await all();
    sessions.removeWhere((s) => s.dappPublicKey == dappPublicKey);
    await _write(sessions);
  }

  /// Records [nonce] against a dapp's session and marks it used.
  ///
  /// Returns false when that nonce has been seen before, which means the
  /// payload is a replay and must not be acted on.
  Future<bool> accept(String dappPublicKey, String nonce, {DateTime? now}) async {
    final sessions = await all();
    final index = sessions.indexWhere((s) => s.dappPublicKey == dappPublicKey);
    if (index == -1) return false;
    if (sessions[index].hasSeen(nonce)) return false;

    sessions[index] = sessions[index].accepting(nonce, (now ?? DateTime.now()).toUtc());
    await _write(sessions);
    return true;
  }

  Future<void> revokeAll() => SecureStore.instance.delete(key: _key);

  Future<void> _write(List<DappSession> sessions) async {
    await SecureStore.instance.write(
      key: _key,
      value: jsonEncode([for (final s in sessions) s.toJson()]),
    );
  }
}
