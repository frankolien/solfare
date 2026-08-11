import 'package:solfare/core/solana/lamports.dart';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/core/network/network_error.dart';
import 'package:solfare/core/solana/preview/preview_engine.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/core/wallet/active_wallet.dart';
import 'package:solfare/core/wallet/keyring.dart';
import 'package:solfare/features/swap/data/datasource/jupiter_datasource.dart';
import 'package:solfare/features/swap/domain/swap_executor.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_event.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_state.dart';

class SwapBloc extends Bloc<SwapEvent, SwapState> {
  late final JupiterDataSource _jupiter;
  late final SwapExecutor _executor;
  late final SolanaRpcDataSource _rpc;
  late final PreviewEngine _preview;

  static int baseUnits(double amount, SwapToken token) =>
      (amount * pow(10, token.decimals)).round();

  // Bumped per quote request; a response whose id no longer matches is a stale
  // one and is dropped.
  int _quoteId = 0;

  // The signed route waiting on the user.
  PreparedSwap? _prepared;

  // Held so a token switch can refresh the balance without the screen having to
  // re-supply the address.
  String? _walletAddress;

  SwapBloc({
    JupiterDataSource? jupiter,
    SolanaRpcDataSource? rpcDataSource,
    PreviewEngine? previewEngine,
  }) : super(const SwapInitial()) {
    _jupiter = jupiter ?? JupiterDataSource();
    _rpc = rpcDataSource ?? SolanaRpcDataSourceImpl();
    _executor = SwapExecutor(jupiter: _jupiter, rpc: _rpc);
    _preview = previewEngine ?? PreviewEngine(_rpc);

    on<LoadTokenListEvent>(_onLoadTokens);
    on<SelectInputTokenEvent>(_onSelectInput);
    on<SelectOutputTokenEvent>(_onSelectOutput);
    on<UpdateInputAmountEvent>(_onUpdateAmount);
    on<FetchQuoteEvent>(_onFetchQuote);
    on<ExecuteSwapEvent>(_onExecuteSwap);
    on<ConfirmSwapEvent>(_onConfirmSwap);
    on<CancelSwapReviewEvent>(_onCancelReview);
    on<FlipTokensEvent>(_onFlipTokens);
    on<LoadInputBalanceEvent>(_onLoadInputBalance);
  }

  Future<void> _onLoadTokens(LoadTokenListEvent event, Emitter<SwapState> emit) async {
    // The pair the user is on, if they are on one. Reloading the list is about
    // which tokens can be chosen, not about which are chosen — resetting to
    // SOL/USDC here threw away a pair that had been preset from a token
    // screen, or picked by hand a moment earlier.
    final current = state;
    final pair = current is SwapReady ? current : null;

    emit(const SwapLoading());
    final tokens = await _tokensFor(_walletAddress ?? event.walletAddress);
    emit(SwapReady(
      tokens: tokens,
      inputToken: pair?.inputToken ?? SwapToken.sol,
      outputToken: pair?.outputToken ?? SwapToken.usdc,
      inputAmount: pair?.inputAmount ?? '',
      inputBalance: pair?.inputBalance,
      balanceUnknown: pair?.balanceUnknown ?? false,
    ));

    // Whatever the list did, the balance still has to arrive. Without this a
    // reload leaves it null with nothing else scheduled to fill it in.
    _refreshBalance();
  }

  void _onSelectInput(SelectInputTokenEvent event, Emitter<SwapState> emit) {
    if (state is SwapReady) {
      final s = state as SwapReady;
      _quoteId++;
      emit(s.copyWith(
        inputToken: event.token,
        outputAmount: null,
        rate: null,
        priceImpact: null,
        inputBalance: null,
        balanceUnknown: false,
      ));
      _refreshBalance();
    }
  }

  void _onSelectOutput(SelectOutputTokenEvent event, Emitter<SwapState> emit) {
    if (state is SwapReady) {
      final s = state as SwapReady;
      // Self-swaps have no route.
      if (event.token.mint == s.inputToken.mint) return;
      _quoteId++;
      emit(s.copyWith(
        outputToken: event.token,
        outputAmount: null,
        rate: null,
        priceImpact: null,
      ));
    }
  }

  Future<void> _onUpdateAmount(UpdateInputAmountEvent event, Emitter<SwapState> emit) async {
    if (state is SwapReady) {
      final s = state as SwapReady;
      final amount = double.tryParse(event.amount);

      if (amount == null || amount <= 0) {
        emit(s.copyWith(inputAmount: event.amount, outputAmount: null, rate: null));
        return;
      }

      final quoteId = ++_quoteId;
      emit(s.copyWith(inputAmount: event.amount, isLoadingQuote: true, error: null));

      try {
        final quoteData = await _jupiter.getQuote(
          inputMint: s.inputToken.mint,
          outputMint: s.outputToken.mint,
          amount: baseUnits(amount, s.inputToken),
        );
        if (quoteId != _quoteId) return;

        // Re-read: `s` was captured before the await, and emitting a copyWith
        // of it would put back whatever pair or amount was current when the
        // request left.
        final now = state;
        if (now is! SwapReady) return;

        final outAmount = int.tryParse(quoteData['outAmount']?.toString() ?? '');
        if (outAmount == null) {
          emit(now.copyWith(
            isLoadingQuote: false,
            error: 'No route for this pair right now.',
          ));
          return;
        }
        final outputDecimal = outAmount / pow(10, now.outputToken.decimals);
        final impact = double.tryParse(quoteData['priceImpactPct']?.toString() ?? '0') ?? 0;

        emit(now.copyWith(
          outputAmount: outputDecimal
              .toStringAsFixed(now.outputToken.decimals > 4 ? 4 : now.outputToken.decimals),
          priceImpact: impact,
          rate: outputDecimal / amount,
          isLoadingQuote: false,
        ));
      } catch (e) {
        if (quoteId != _quoteId) return;
        final now = state;
        if (now is! SwapReady) return;
        emit(now.copyWith(isLoadingQuote: false, error: _quoteError(e)));
      }
    }
  }

  // Jupiter's sentence when it gave one. "Swapping of jlWSOL is not supported"
  // tells the user the token cannot be routed; "Failed to get quote" tells
  // them the app is broken.
  static String _quoteError(Object error) {
    if (error is SwapUnavailableException) return error.message;
    return friendlyNetworkError(error);
  }

  void _onFlipTokens(FlipTokensEvent event, Emitter<SwapState> emit) {
    if (state is SwapReady) {
      final s = state as SwapReady;
      _quoteId++;
      emit(s.copyWith(
        inputToken: s.outputToken,
        outputToken: s.inputToken,
        inputAmount: '',
        outputAmount: null,
        rate: null,
        priceImpact: null,
        inputBalance: null,
        balanceUnknown: false,
      ));
      _refreshBalance();
    }
  }

  Future<void> _onLoadInputBalance(
    LoadInputBalanceEvent event,
    Emitter<SwapState> emit,
  ) async {
    // Recorded before the guard: returning early without it left
    // _refreshBalance with no address to use, for the life of the screen.
    _walletAddress = event.walletAddress;
    if (state is! SwapReady) return;
    final s = state as SwapReady;
    final balance = await _balanceOf(s.inputToken, event.walletAddress);
    if (state is SwapReady) {
      emit((state as SwapReady).copyWith(
        inputBalance: balance,
        balanceUnknown: balance == null,
      ));
    }
  }

  void _refreshBalance() {
    final address = _walletAddress;
    if (address != null) add(LoadInputBalanceEvent(address));
  }

  // The curated list is a starting point, not the universe. A wallet holding
  // jitoSOL could not swap it, because the list of nine did not name it — the
  // one token set that must always be swappable is the one the user owns.
  Future<List<SwapToken>> _tokensFor(String? owner) async {
    final popular = _jupiter.getTokenList();
    if (owner == null || owner.isEmpty) return popular;

    try {
      final held = await _rpc.getTokens(owner);
      final bySymbol = <String, SwapToken>{
        for (final t in popular) t.mint: t,
      };

      // Held first, so what the user actually owns is at the top of the picker.
      final ordered = <SwapToken>[SwapToken.sol];
      for (final t in held) {
        if (t.mint == SwapToken.sol.mint || t.balance <= 0) continue;
        ordered.add(SwapToken(
          mint: t.mint,
          symbol: t.symbol.isEmpty ? _shortMint(t.mint) : t.symbol,
          name: t.name.isEmpty ? t.symbol : t.name,
          decimals: t.decimals,
          logoUrl: t.imageUrl ?? bySymbol[t.mint]?.logoUrl,
          priceUsd: t.priceUsd,
        ));
      }

      final seen = {for (final t in ordered) t.mint};
      for (final t in popular) {
        if (seen.add(t.mint)) ordered.add(t);
      }
      return ordered;
    } catch (e) {
      debugLog('[Swap] could not read held tokens: $e');
      return popular;
    }
  }

  static String _shortMint(String mint) => mint.length <= 8
      ? mint
      : '${mint.substring(0, 4)}…${mint.substring(mint.length - 4)}';

  // Native SOL lives in the account itself; everything else is an SPL balance
  // spread over the owner's token accounts.
  Future<double?> _balanceOf(SwapToken token, String owner) async {
    try {
      if (token.mint == SwapToken.sol.mint) {
        return Lamports.toSol(await _rpc.getBalance(owner));
      }
      return await _rpc.getTokenBalance(owner, token.mint);
    } catch (e) {
      debugLog('[Swap] balance lookup failed: $e');
      return null;
    }
  }

  Future<void> _onFetchQuote(FetchQuoteEvent event, Emitter<SwapState> emit) async {
    if (state is! SwapReady) return;
    final s = state as SwapReady;

    final amount = double.tryParse(s.inputAmount);
    if (amount == null || amount <= 0) return;

    emit(s.copyWith(isLoadingQuote: true, error: null));

    try {
      final lamports = (amount * pow(10, s.inputToken.decimals)).toInt();

      final quoteData = await _jupiter.getQuote(
        inputMint: s.inputToken.mint,
        outputMint: s.outputToken.mint,
        amount: lamports,
      );

      final outAmount = int.parse(quoteData['outAmount'].toString());
      final outputDecimal = outAmount / pow(10, s.outputToken.decimals);
      final impact = double.tryParse(quoteData['priceImpactPct']?.toString() ?? '0') ?? 0;
      final rate = outputDecimal / amount;

      emit(s.copyWith(
        outputAmount: outputDecimal.toStringAsFixed(s.outputToken.decimals > 4 ? 4 : s.outputToken.decimals),
        priceImpact: impact,
        rate: rate,
        isLoadingQuote: false,
      ));
    } catch (e) {
      emit(s.copyWith(isLoadingQuote: false, error: _quoteError(e)));
    }
  }

  // Builds and signs the route, then hands it to the user rather than to the
  // network.
  Future<void> _onExecuteSwap(ExecuteSwapEvent event, Emitter<SwapState> emit) async {
    if (state is! SwapReady) return;
    final s = state as SwapReady;

    final amount = double.tryParse(s.inputAmount);
    if (amount == null || amount <= 0) return;

    emit(const SwapExecuting());

    try {
      final mnemonic = await ActiveWallet.mnemonic();
      if (mnemonic == null) throw Exception('No wallet found');
      final keyPair = await Keyring.keyPairFor(mnemonic);

      final prepared = await _executor.prepare(
        inputMint: s.inputToken.mint,
        outputMint: s.outputToken.mint,
        amountRaw: baseUnits(amount, s.inputToken),
        walletAddress: event.walletAddress,
        keyPair: keyPair,
      );
      _prepared = prepared;

      final preview = await _preview.previewSigned(
        base64Tx: prepared.signedTransaction,
        ownerAddress: event.walletAddress,
        symbols: {
          s.inputToken.mint: s.inputToken.symbol,
          s.outputToken.mint: s.outputToken.symbol,
        },
      );

      emit(SwapReviewing(ready: s, preview: preview));
    } on SwapUnavailableException catch (e) {
      _prepared = null;
      emit(SwapError(e.message));
    } catch (e) {
      _prepared = null;
      emit(SwapError('Swap failed: $e'));
    }
  }

  void _onCancelReview(CancelSwapReviewEvent event, Emitter<SwapState> emit) {
    final current = state;
    if (current is! SwapReviewing) return;
    _prepared = null;
    emit(current.ready);
  }

  Future<void> _onConfirmSwap(ConfirmSwapEvent event, Emitter<SwapState> emit) async {
    final prepared = _prepared;
    if (state is! SwapReviewing || prepared == null) return;

    emit(const SwapExecuting());
    try {
      final result = await _executor.send(prepared);
      _prepared = null;
      if (result.isConfirmed) {
        emit(SwapSuccess(result.signature!));
        return;
      }
      emit(SwapError(result.error!));
    } catch (e) {
      _prepared = null;
      emit(SwapError('Swap failed: $e'));
    }
  }
}
