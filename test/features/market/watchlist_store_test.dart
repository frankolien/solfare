import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfare/features/market/data/watchlist_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const a = 'AymATz4TCL9sWNEEV9Kvyz45CHVhDZ6kUgjTJPzLpU9P';
  const b = '5GgRAEmv8ZxF2PR5hY72Qs5x1bnQ6UK2RbTPoqJ3wSwW';

  late WatchlistStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = WatchlistStore.instance..resetForTest();
    await store.load();
  });

  test('stars go on and come off', () async {
    await store.add(a);
    expect(store.contains(a), isTrue);
    await store.remove(a);
    expect(store.contains(a), isFalse);
  });

  test('toggle is add or remove, depending', () async {
    await store.toggle(a);
    expect(store.contains(a), isTrue);
    await store.toggle(a);
    expect(store.contains(a), isFalse);
  });

  test('order is the order they were starred, not any ranking of ours', () async {
    await store.add(b);
    await store.add(a);
    expect(store.mints.value, [b, a]);
  });

  test('starring the same mint twice does not list it twice', () async {
    await store.add(a);
    await store.add(a);
    expect(store.mints.value, [a]);
  });

  test('the notifier fires so every star on screen flips together', () async {
    var fired = 0;
    void listener() => fired++;
    store.mints.addListener(listener);
    await store.add(a);
    await store.remove(a);
    store.mints.removeListener(listener);
    expect(fired, 2);
  });

  test('an empty mint is not something to star', () async {
    await store.add('');
    expect(store.mints.value, isEmpty);
  });

  test('the list survives a restart', () async {
    await store.add(a);
    await store.add(b);

    store.resetForTest();
    await store.load();
    expect(store.mints.value, [a, b]);
  });

  test('nothing stored reads as nothing starred, not as an error', () async {
    SharedPreferences.setMockInitialValues({});
    store.resetForTest();
    await store.load();
    expect(store.mints.value, isEmpty);
  });
}
