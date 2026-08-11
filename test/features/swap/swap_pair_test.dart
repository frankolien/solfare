import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_bloc.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_event.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_state.dart';

void main() {
  const jitoSol = SwapToken(
    mint: 'J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn',
    symbol: 'JitoSOL',
    name: 'Jito Staked SOL',
    decimals: 9,
  );

  const pump = SwapToken(
    mint: 'pumpCmXqMfrsAkQ5r49WcJnRayYRqmXz6ae8H7H9Dfn',
    symbol: 'PUMP',
    name: 'Pump',
    decimals: 6,
  );

  late SwapBloc bloc;

  setUp(() => bloc = SwapBloc());
  tearDown(() => bloc.close());

  Future<SwapReady> ready() async =>
      await bloc.stream.firstWhere((s) => s is SwapReady) as SwapReady;

  test('a cold open lands on SOL to USDC', () async {
    bloc.add(const LoadTokenListEvent());

    final state = await ready();
    expect(state.inputToken.symbol, 'SOL');
    expect(state.outputToken.symbol, 'USDC');
  });

  test('reloading the list keeps the pair the user is on', () async {
    // Opening swap from a token screen presets the output, and the address
    // arriving a moment later reloads the list. That reload used to reset the
    // pair to SOL/USDC, so the token the user came to buy was discarded.
    bloc.add(const LoadTokenListEvent());
    await ready();

    bloc.add(const SelectOutputTokenEvent(jitoSol));
    await bloc.stream.firstWhere(
        (s) => s is SwapReady && s.outputToken.symbol == 'JitoSOL');

    bloc.add(const LoadTokenListEvent(walletAddress: 'not-a-real-address'));
    // Settled rather than awaited: a reload that changes nothing now emits
    // nothing, because the rebuilt state is equal to the current one.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final after = bloc.state as SwapReady;

    expect(after.outputToken.symbol, 'JitoSOL');
    expect(after.inputToken.symbol, 'SOL');
  });

  test('buying a token pays with SOL, whatever was last sold', () async {
    bloc.add(const LoadTokenListEvent());
    await ready();

    // Left over from a previous swap, which is exactly what preserving the
    // pair across a reload makes possible.
    bloc.add(const SelectInputTokenEvent(jitoSol));
    await bloc.stream
        .firstWhere((s) => s is SwapReady && s.inputToken.symbol == 'JitoSOL');

    bloc.add(const OpenWithOutputEvent(pump));
    final after = await bloc.stream.firstWhere(
        (s) => s is SwapReady && s.outputToken.symbol == 'PUMP') as SwapReady;

    expect(after.inputToken.symbol, 'SOL');
    expect(after.outputToken.symbol, 'PUMP');
    expect(after.inputAmount, isEmpty);
  });

  test('the preset survives being dispatched before the list has loaded',
      () async {
    // What initState actually does: both events back to back, with no await
    // between them. Different event types have separate handlers in bloc, so
    // they run concurrently — the earlier tests awaited ready() first and so
    // never reproduced this.
    bloc.add(const LoadTokenListEvent());
    bloc.add(const OpenWithOutputEvent(pump));
    // And the reload once the address resolves, which is the one that does a
    // network call and therefore lands last.
    bloc.add(const LoadTokenListEvent(walletAddress: 'not-a-real-address'));

    await Future<void>.delayed(const Duration(milliseconds: 400));
    final after = bloc.state as SwapReady;

    expect(after.outputToken.symbol, 'PUMP');
    expect(after.inputToken.symbol, 'SOL');
  });

  test('buying SOL pays with USDC, since nothing swaps for itself', () async {
    bloc.add(const LoadTokenListEvent());
    await ready();

    bloc.add(const OpenWithOutputEvent(SwapToken.sol));
    final after = await bloc.stream.firstWhere(
        (s) => s is SwapReady && s.outputToken.symbol == 'SOL') as SwapReady;

    expect(after.inputToken.symbol, 'USDC');
  });

  test('the reload after the address arrives keeps the bought pair', () async {
    // The exact sequence the screen produces: list, preset, then the
    // address-aware reload a moment later.
    bloc.add(const LoadTokenListEvent());
    await ready();
    bloc.add(const OpenWithOutputEvent(pump));
    await bloc.stream
        .firstWhere((s) => s is SwapReady && s.outputToken.symbol == 'PUMP');

    bloc.add(const LoadTokenListEvent(walletAddress: 'not-a-real-address'));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final after = bloc.state as SwapReady;

    expect(after.inputToken.symbol, 'SOL');
    expect(after.outputToken.symbol, 'PUMP');
  });

  test('a typed amount survives the reload too', () async {
    bloc.add(const LoadTokenListEvent());
    await ready();

    bloc.add(const UpdateInputAmountEvent('1.5'));
    await bloc.stream
        .firstWhere((s) => s is SwapReady && s.inputAmount == '1.5');

    bloc.add(const LoadTokenListEvent());
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final after = bloc.state as SwapReady;

    expect(after.inputAmount, '1.5');
  });
}
