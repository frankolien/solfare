import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/solana/session/dapp_session.dart';
import 'package:solfare/core/solana/session/session_store.dart';
import 'package:solfare/features/settings/presentation/screens/connected_apps_screen.dart';

/// Keeps sessions in memory so the screen can be driven without secure
/// storage. Records revocations, since that is the whole point of the screen.
class _FakeStore implements SessionStore {
  List<DappSession> sessions;
  final List<String> revoked = [];
  bool revokedAll = false;

  _FakeStore(this.sessions);

  @override
  Future<List<DappSession>> active({DateTime? now}) async => sessions;

  @override
  Future<void> revoke(String dappPublicKey) async {
    revoked.add(dappPublicKey);
    sessions = sessions.where((s) => s.dappPublicKey != dappPublicKey).toList();
  }

  @override
  Future<void> revokeAll() async {
    revokedAll = true;
    sessions = const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used by this test');
}

void main() {
  DappSession session(String origin, {Duration idle = const Duration(hours: 2)}) {
    final used = DateTime.now().subtract(idle);
    return DappSession(
      origin: origin,
      dappPublicKey: 'key-$origin',
      sessionPrivateKey: 'private',
      walletAddress: '2jBAqgtrrvteWarFeqko1nhRmhHoMU2gLxYHWRDaQPgB',
      sessionToken: 'token',
      createdAt: used,
      lastUsedAt: used,
    );
  }

  Future<void> pump(WidgetTester tester, _FakeStore store) async {
    await tester.pumpWidget(
      MaterialApp(home: ConnectedAppsScreen(store: store)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty list says so rather than showing nothing', (tester) async {
    await pump(tester, _FakeStore(const []));
    expect(find.text('No apps connected'), findsOneWidget);
    expect(find.text('Revoke all'), findsNothing);
  });

  testWidgets('each app is listed by its origin', (tester) async {
    // The origin, not a name the app chose: a dapp picks its own label and
    // does not pick its domain.
    await pump(tester, _FakeStore([session('jup.ag'), session('tensor.trade')]));
    expect(find.text('jup.ag'), findsOneWidget);
    expect(find.text('tensor.trade'), findsOneWidget);
  });

  testWidgets('the wallet a session can sign for is shown', (tester) async {
    await pump(tester, _FakeStore([session('jup.ag')]));
    expect(find.text('2jBA…QPgB'), findsOneWidget);
  });

  testWidgets('a session says it lapses on its own, so revoking is not the only way out',
      (tester) async {
    await pump(tester, _FakeStore([session('jup.ag', idle: const Duration(days: 2))]));
    expect(find.textContaining('lapses in'), findsOneWidget);
  });

  testWidgets('a session near its idle limit says it lapses today', (tester) async {
    final almostStale = DappSession.maxIdle - const Duration(minutes: 30);
    await pump(tester, _FakeStore([session('jup.ag', idle: almostStale)]));
    expect(find.textContaining('lapses today'), findsOneWidget);
  });

  testWidgets('disconnecting asks first, and cancelling changes nothing', (tester) async {
    final store = _FakeStore([session('jup.ag')]);
    await pump(tester, store);

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect jup.ag?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.revoked, isEmpty);
    expect(find.text('jup.ag'), findsOneWidget);
  });

  testWidgets('confirming disconnects that app and no other', (tester) async {
    final store = _FakeStore([session('jup.ag'), session('tensor.trade')]);
    await pump(tester, store);

    await tester.tap(find.text('Disconnect').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Disconnect').last);
    await tester.pumpAndSettle();

    expect(store.revoked, ['key-jup.ag']);
    expect(find.text('jup.ag'), findsNothing);
    expect(find.text('tensor.trade'), findsOneWidget);
  });

  testWidgets('revoke all is not offered for a single app', (tester) async {
    await pump(tester, _FakeStore([session('jup.ag')]));
    expect(find.text('Revoke all'), findsNothing);
  });

  testWidgets('revoke all appears once there is more than one', (tester) async {
    await pump(tester, _FakeStore([session('jup.ag'), session('tensor.trade')]));
    expect(find.text('Revoke all'), findsOneWidget);
  });

  testWidgets('revoke all clears the list', (tester) async {
    final store = _FakeStore([session('jup.ag'), session('tensor.trade')]);
    await pump(tester, store);

    await tester.tap(find.text('Revoke all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect all'));
    await tester.pumpAndSettle();

    expect(store.revokedAll, isTrue);
    expect(find.text('No apps connected'), findsOneWidget);
  });
}
