import 'dart:async';
import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:solfare/core/solana/preview/preview_engine.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/core/wallet/active_wallet.dart';
import 'package:solfare/core/wallet/keyring.dart';
import 'package:solfare/features/market/presentation/bloc/buy_event.dart';
import 'package:solfare/features/market/presentation/bloc/buy_state.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';
import 'package:solfare/features/swap/domain/swap_executor.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';

/// Buying an asset from the market: quote, review, execute.
///
/// The route is signed before the preview is shown, which reads backwards and
/// is not. Signing is local; nothing leaves the device until [BuyConfirmed].
/// Simulating the route Jupiter actually built is the only way to show the
/// balances that will really move, rather than Jupiter's description of them.
class BuyBloc extends Bloc<BuyEvent, BuyState> {
  final SwapExecutor _executor;
  final SolanaRpcDataSource _rpc;
  final PreviewEngine _preview;

  static const Duration quoteDebounce = Duration(milliseconds: 350);

  Timer? _quoteTimer;

  /// Bumped per quote so a slow response for an earlier amount cannot land on
  /// a later one and quote a number the user is no longer looking at.
  int _quoteId = 0;

  PreparedSwap? _prepared;

  BuyBloc({
    SwapExecutor? executor,
    SolanaRpcDataSource? rpc,
    PreviewEngine? preview,
  })  : _rpc = rpc ?? SolanaRpcDataSourceImpl(),
        _executor = executor ?? SwapExecutor(rpc: rpc),
        _preview = preview ?? PreviewEngine(rpc ?? SolanaRpcDataSourceImpl()),
        super(const BuyState()) {
    on<BuyStarted>(_onStarted);
    on<BuyPayWithChanged>(_onPayWithChanged);
    on<BuyAmountChanged>(_onAmountChanged);
    on<_QuoteArrived>(_onQuoteArrived);
    on<BuyReviewRequested>(_onReviewRequested);
    on<BuyReviewDismissed>(_onReviewDismissed);
    on<BuyConfirmed>(_onConfirmed);
  }

  @override
  Future<void> close() {
    _quoteTimer?.cancel();
    return super.close();
  }

  Future<void> _onStarted(BuyStarted event, Emitter<BuyState> emit) async {
    emit(BuyState(asset: event.asset, walletAddress: event.walletAddress));
    await _loadBalance(emit);
  }

  Future<void> _onPayWithChanged(BuyPayWithChanged event, Emitter<BuyState> emit) async {
    if (event.token.mint == state.payWith.mint) return;
    emit(state.copyWith(
      payWith: event.token,
      amountText: '',
      isQuoting: false,
      clearQuote: true,
      clearBalance: true,
      clearError: true,
    ));
    await _loadBalance(emit);
  }

  Future<void> _loadBalance(Emitter<BuyState> emit) async {
    final owner = state.walletAddress;
    if (owner.isEmpty) return;
    final payWith = state.payWith;
    try {
      final balance = payWith.mint == SwapToken.sol.mint
          ? await _rpc.getBalance(owner) / 1000000000
          : await _rpc.getTokenBalance(owner, payWith.mint);
      // The user may have switched what they are paying with while this was
      // in flight; a USDC balance shown under SOL would be a lie.
      if (state.payWith.mint != payWith.mint) return;
      emit(state.copyWith(balance: balance));
    } catch (e) {
      debugLog('[Buy] balance lookup failed: $e');
    }
  }

  void _onAmountChanged(BuyAmountChanged event, Emitter<BuyState> emit) {
    _quoteTimer?.cancel();
    _quoteId++;

    final next = state.copyWith(
      amountText: event.amount,
      clearQuote: true,
      clearError: true,
      isQuoting: false,
    );
    emit(next);

    if (next.amount == null || next.asset == null) return;
    emit(next.copyWith(isQuoting: true));
    _quoteTimer = Timer(quoteDebounce, () => _fetchQuote(next));
  }

  Future<void> _fetchQuote(BuyState snapshot) async {
    final id = ++_quoteId;
    final asset = snapshot.asset;
    final amount = snapshot.amount;
    if (asset == null || amount == null) return;

    try {
      final quote = await _executor.quote(
        inputMint: snapshot.payWith.mint,
        outputMint: asset.id,
        amountRaw: (amount * pow(10, snapshot.payWith.decimals)).round(),
      );
      if (id != _quoteId || isClosed) return;
      add(_QuoteArrived(outAmountRaw: quote.outAmountRaw));
    } catch (e) {
      debugLog('[Buy] quote failed: $e');
      if (id != _quoteId || isClosed) return;
      add(const _QuoteArrived(error: 'No route for this amount right now.'));
    }
  }

  void _onQuoteArrived(_QuoteArrived event, Emitter<BuyState> emit) {
    emit(state.copyWith(
      isQuoting: false,
      quotedOutRaw: event.outAmountRaw,
      error: event.error,
      clearQuote: event.outAmountRaw == null,
      clearError: event.error == null,
    ));
  }

  Future<void> _onReviewRequested(BuyReviewRequested event, Emitter<BuyState> emit) async {
    final asset = state.asset;
    final amount = state.amount;
    if (asset == null || amount == null) return;

    emit(state.copyWith(status: BuyStatus.preparing, clearError: true, clearPreview: true));

    try {
      final mnemonic = await ActiveWallet.mnemonic();
      if (mnemonic == null) throw Exception('No wallet is active.');
      final keyPair = await Keyring.keyPairFromMnemonic(mnemonic);

      final prepared = await _executor.prepare(
        inputMint: state.payWith.mint,
        outputMint: asset.id,
        amountRaw: (amount * pow(10, state.payWith.decimals)).round(),
        walletAddress: state.walletAddress,
        keyPair: keyPair,
      );
      _prepared = prepared;

      final preview = await _preview.previewSigned(
        base64Tx: prepared.signedTransaction,
        ownerAddress: state.walletAddress,
        symbols: {
          asset.id: asset.symbol,
          state.payWith.mint: state.payWith.symbol,
        },
      );

      emit(state.copyWith(
        status: BuyStatus.review,
        preview: preview,
        quotedOutRaw: prepared.outAmountRaw,
      ));
    } on SwapUnavailableException catch (e) {
      emit(state.copyWith(status: BuyStatus.editing, error: e.message));
    } catch (e) {
      debugLog('[Buy] prepare failed: $e');
      emit(state.copyWith(
        status: BuyStatus.editing,
        error: 'Could not prepare this purchase.',
      ));
    }
  }

  void _onReviewDismissed(BuyReviewDismissed event, Emitter<BuyState> emit) {
    // The signed route is dropped with the review. Reusing it after the user
    // has changed their mind would broadcast a transaction they backed out of.
    _prepared = null;
    emit(state.copyWith(status: BuyStatus.editing, clearPreview: true, clearError: true));
  }

  Future<void> _onConfirmed(BuyConfirmed event, Emitter<BuyState> emit) async {
    final prepared = _prepared;
    if (prepared == null || state.status != BuyStatus.review) return;

    emit(state.copyWith(status: BuyStatus.sending));
    try {
      final result = await _executor.send(prepared);
      _prepared = null;
      if (result.isConfirmed) {
        emit(state.copyWith(status: BuyStatus.done, signature: result.signature));
        return;
      }
      emit(state.copyWith(status: BuyStatus.failed, error: result.error));
    } catch (e) {
      debugLog('[Buy] execute failed: $e');
      _prepared = null;
      emit(state.copyWith(status: BuyStatus.failed, error: 'The purchase did not go through.'));
    }
  }
}

/// Internal: a debounced quote coming back. Routed through the event loop so
/// the emit happens inside a handler rather than after one has returned.
class _QuoteArrived extends BuyEvent {
  final int? outAmountRaw;
  final String? error;

  const _QuoteArrived({this.outAmountRaw, this.error});

  @override
  List<Object?> get props => [outAmountRaw, error];
}
