import 'package:solfare/core/solana/lamports.dart';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  /// Base units for [amount] of [token].
  ///
  /// Shared because the two call sites had drifted: the quote truncated and
  /// the execute rounded, so 8.7 USDC quoted 8699999 and swapped 8700000 —
  /// the user was shown a price for an amount the swap did not make.
  static int baseUnits(double amount, SwapToken token) =>
      (amount * pow(10, token.decimals)).round();

  /// Bumped per quote request; a response whose id no longer matches is a
  /// stale one and is dropped. Bloc 8's default transformer is concurrent
  /// and a quote fires on every keystroke, so the last response to *return*
  /// used to win rather than the last keystroke: type "12", backspace to
  /// "1", and the field read 1 while the state said 12 — which is the amount
  /// the execute then prepared.
  int _quoteId = 0;

  /// The signed route waiting on the user. Dropped the moment they back out.
  PreparedSwap? _prepared;

  // Held so a token switch can refresh the balance without the screen
  // having to re-supply the address.
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
    emit(const SwapLoading());
    final tokens = _jupiter.getTokenList();
    emit(SwapReady(
      tokens: tokens,
      inputToken: SwapToken.sol,
      outputToken: SwapToken.usdc,
    ));
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
      ));
      _refreshBalance();
    }
  }

  void _onSelectOutput(SelectOutputTokenEvent event, Emitter<SwapState> emit) {
    if (state is SwapReady) {
      final s = state as SwapReady;
      // Self-swaps have no route. Buying SOL from the market screen set the
      // output to wrapped SOL, which is also the default input, so the form
      // sat on SOL→SOL and every amount produced "Failed to get quote".
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

        // Re-read: `s` was captured before the await, and emitting a
        // copyWith of it would put back whatever pair or amount was current
        // when the request left.
        final now = state;
        if (now is! SwapReady) return;

        final outAmount = int.tryParse(quoteData['outAmount']?.toString() ?? '');
        if (outAmount == null) {
          emit(now.copyWith(isLoadingQuote: false, error: 'Failed to get quote'));
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
        emit(now.copyWith(isLoadingQuote: false, error: 'Failed to get quote'));
      }
    }
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
      ));
      _refreshBalance();
    }
  }

  Future<void> _onLoadInputBalance(
    LoadInputBalanceEvent event,
    Emitter<SwapState> emit,
  ) async {
    if (state is! SwapReady) return;
    _walletAddress = event.walletAddress;
    final s = state as SwapReady;
    final balance = await _balanceOf(s.inputToken, event.walletAddress);
    if (state is SwapReady) {
      emit((state as SwapReady).copyWith(inputBalance: balance));
    }
  }

  void _refreshBalance() {
    final address = _walletAddress;
    if (address != null) add(LoadInputBalanceEvent(address));
  }

  /// Native SOL lives in the account itself; everything else is an SPL
  /// balance spread over the owner's token accounts.
  /// Null on failure, which SwapLimits.covers reads as "unknown, do not
  /// block". Returning 0 made a transient RPC error indistinguishable from
  /// an empty wallet, so one failed lookup showed "Insufficient SOL" on a
  /// funded wallet — permanently, since nothing retries until the user
  /// switches tokens.
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
      emit(s.copyWith(isLoadingQuote: false, error: 'Failed to get quote'));
    }
  }

  /// Builds and signs the route, then hands it to the user rather than to
  /// the network.
  ///
  /// The preview comes from simulating the transaction Jupiter actually
  /// built, which is the only way to show what the swap moves rather than
  /// what the route says it moves.
  Future<void> _onExecuteSwap(ExecuteSwapEvent event, Emitter<SwapState> emit) async {
    if (state is! SwapReady) return;
    final s = state as SwapReady;

    final amount = double.tryParse(s.inputAmount);
    if (amount == null || amount <= 0) return;

    emit(const SwapExecuting());

    try {
      final mnemonic = await ActiveWallet.mnemonic();
      if (mnemonic == null) throw Exception('No wallet found');
      final keyPair = await Keyring.keyPairFromMnemonic(mnemonic);

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
