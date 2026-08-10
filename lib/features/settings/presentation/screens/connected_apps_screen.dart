import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:solfare/core/solana/session/dapp_session.dart';
import 'package:solfare/core/solana/session/session_store.dart';

/// Every app that can currently ask this wallet to sign.
class ConnectedAppsScreen extends StatefulWidget {
  /// [store] is a test seam; the app always uses the default.
  const ConnectedAppsScreen({super.key, SessionStore? store}) : _store = store;

  final SessionStore? _store;

  @override
  State<ConnectedAppsScreen> createState() => _ConnectedAppsScreenState();
}

class _ConnectedAppsScreenState extends State<ConnectedAppsScreen> {
  static const _background = Color(0xFF0a0b12);
  static const _card = Color(0xFF15191F);
  static const _danger = Color(0xFFE03131);

  late final SessionStore _store = widget._store ?? const SessionStore();

  List<DappSession>? _sessions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // active() drops anything past its idle window as it reads, so a session
    // that has already lapsed is never offered as something to revoke.
    final sessions = await _store.active();
    if (!mounted) return;
    setState(() => _sessions = sessions);
  }

  Future<void> _revoke(DappSession session) async {
    final confirmed = await _confirm(
      title: 'Disconnect ${session.origin}?',
      detail: 'It will have to ask again before it can request another '
          'signature from this wallet.',
      action: 'Disconnect',
    );
    if (confirmed != true) return;

    await _store.revoke(session.dappPublicKey);
    await _load();
  }

  Future<void> _revokeAll() async {
    final confirmed = await _confirm(
      title: 'Disconnect everything?',
      detail: 'Every app below will have to ask again before it can request '
          'another signature.',
      action: 'Disconnect all',
    );
    if (confirmed != true) return;

    await _store.revokeAll();
    await _load();
  }

  Future<bool?> _confirm({
    required String title,
    required String detail,
    required String action,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'FKGrotesk',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          detail,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontFamily: 'FKGrotesk',
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'FKGrotesk'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              action,
              style: const TextStyle(
                color: _danger,
                fontSize: 12,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _header(sessions),
            const SizedBox(height: 8),
            Expanded(
              child: sessions == null
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
                      ),
                    )
                  : sessions.isEmpty
                      ? _empty()
                      : _list(sessions),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(List<DappSession>? sessions) {
    final canRevokeAll = sessions != null && sessions.length > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Connected apps',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: canRevokeAll
                ? GestureDetector(
                    onTap: _revokeAll,
                    behavior: HitTestBehavior.opaque,
                    child: const Text(
                      'Revoke all',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: _danger,
                        fontSize: 9,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.document_code, color: Colors.grey[700], size: 26),
            const SizedBox(height: 14),
            const Text(
              'No apps connected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Apps you connect will appear here, and you can disconnect them '
              'at any time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
                fontFamily: 'FKGrotesk',
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<DappSession> sessions) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      itemCount: sessions.length + 1,
      itemBuilder: (context, index) {
        if (index == sessions.length) return _footer();
        return _tile(sessions[index]);
      },
    );
  }

  Widget _tile(DappSession session) {
    final now = DateTime.now();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The origin, not a name the app chose for itself.
                Text(
                  session.origin,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  // A session is bound to one account, so which one it can sign
                  // for is part of what was granted.
                  _shorten(session.walletAddress),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 9,
                    fontFamily: 'FKGroteskSemiMono',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_ago(session.lastUsedAt, now)} · ${_lapses(session.lastUsedAt, now)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 9, fontFamily: 'FKGrotesk'),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _revoke(session),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text(
              'Disconnect',
              style: TextStyle(
                color: _danger,
                fontSize: 10,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'Disconnecting removes the key this device shares with an app. It '
        'cannot read anything sent afterwards, and has to ask again before it '
        'can request another signature.',
        style: TextStyle(
          color: Colors.grey[700],
          fontSize: 9,
          fontFamily: 'FKGrotesk',
          height: 1.7,
        ),
      ),
    );
  }

  static String _shorten(String address) => address.length <= 12
      ? address
      : '${address.substring(0, 4)}…${address.substring(address.length - 4)}';

  static String _ago(DateTime at, DateTime now) {
    final elapsed = now.difference(at);
    if (elapsed.inMinutes < 1) return 'Used just now';
    if (elapsed.inHours < 1) return 'Used ${elapsed.inMinutes}m ago';
    if (elapsed.inDays < 1) return 'Used ${elapsed.inHours}h ago';
    return 'Used ${elapsed.inDays}d ago';
  }

  // Sessions expire on their own.
  static String _lapses(DateTime lastUsedAt, DateTime now) {
    final left = DappSession.maxIdle - now.difference(lastUsedAt);
    if (left.inDays >= 1) return 'lapses in ${left.inDays}d';
    if (left.inHours >= 1) return 'lapses in ${left.inHours}h';
    return 'lapses today';
  }
}
