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
    final after = await bloc.stream.firstWhere(
        (s) => s is SwapReady && s.tokens.isNotEmpty) as SwapReady;

    expect(after.outputToken.symbol, 'JitoSOL');
    expect(after.inputToken.symbol, 'SOL');
  });

  test('a typed amount survives the reload too', () async {
    bloc.add(const LoadTokenListEvent());
    await ready();

    bloc.add(const UpdateInputAmountEvent('1.5'));
    await bloc.stream
        .firstWhere((s) => s is SwapReady && s.inputAmount == '1.5');

    bloc.add(const LoadTokenListEvent());
    final after = await bloc.stream.firstWhere(
        (s) => s is SwapReady && s.tokens.isNotEmpty) as SwapReady;

    expect(after.inputAmount, '1.5');
  });
}
