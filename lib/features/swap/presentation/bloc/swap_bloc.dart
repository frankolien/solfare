import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solana/encoder.dart' as encoder;
import 'package:solana/solana.dart' as solana;
import 'package:solfare/core/solana/transaction_service.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/core/wallet/active_wallet.dart';
import 'package:solfare/core/wallet/keyring.dart';
import 'package:solfare/features/swap/data/datasource/jupiter_datasource.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_event.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_state.dart';

class SwapBloc extends Bloc<SwapEvent, SwapState> {
  late final JupiterDataSource _jupiter;
  late final TransactionService _txService;
  late final SolanaRpcDataSource _rpc;

  // Held so a token switch can refresh the balance without the screen
  // having to re-supply the address.
  String? _walletAddress;

  SwapBloc({JupiterDataSource? jupiter, SolanaRpcDataSource? rpcDataSource})
      : super(const SwapInitial()) {
    _jupiter = jupiter ?? JupiterDataSource();
    _rpc = rpcDataSource ?? SolanaRpcDataSourceImpl();
    _txService = TransactionService(_rpc);

    on<LoadTokenListEvent>(_onLoadTokens);
    on<SelectInputTokenEvent>(_onSelectInput);
    on<SelectOutputTokenEvent>(_onSelectOutput);
    on<UpdateInputAmountEvent>(_onUpdateAmount);
    on<FetchQuoteEvent>(_onFetchQuote);
    on<ExecuteSwapEvent>(_onExecuteSwap);
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
      emit(s.copyWith(
        inputToken: event.token,
        outputAmount: null,
        rate: null,
        inputBalance: null,
      ));
      _refreshBalance();
    }
  }

  void _onSelectOutput(SelectOutputTokenEvent event, Emitter<SwapState> emit) {
    if (state is SwapReady) {
      final s = state as SwapReady;
      emit(s.copyWith(outputToken: event.token, outputAmount: null, rate: null));
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

      emit(s.copyWith(inputAmount: event.amount, isLoadingQuote: true, error: null));

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
          inputAmount: event.amount,
          outputAmount: outputDecimal.toStringAsFixed(s.outputToken.decimals > 4 ? 4 : s.outputToken.decimals),
          priceImpact: impact,
          rate: rate,
          isLoadingQuote: false,
        ));
      } catch (e) {
        emit(s.copyWith(inputAmount: event.amount, isLoadingQuote: false, error: 'Failed to get quote'));
      }
    }
  }

  void _onFlipTokens(FlipTokensEvent event, Emitter<SwapState> emit) {
    if (state is SwapReady) {
      final s = state as SwapReady;
      emit(s.copyWith(
        inputToken: s.outputToken,
        outputToken: s.inputToken,
        inputAmount: '',
        outputAmount: null,
        rate: null,
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
  Future<double> _balanceOf(SwapToken token, String owner) async {
    try {
      if (token.mint == SwapToken.sol.mint) {
        return await _rpc.getBalance(owner) / 1000000000;
      }
      return await _rpc.getTokenBalance(owner, token.mint);
    } catch (e) {
      debugLog('[Swap] balance lookup failed: $e');
      return 0;
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

      // The displayed quote was fetched without a taker, so it carries no
      // transaction. Re-order with the wallet attached to get the built
      // transaction and the requestId /execute is keyed on.
      final lamports = (amount * pow(10, s.inputToken.decimals)).round();
      final order = await _jupiter.getQuote(
        inputMint: s.inputToken.mint,
        outputMint: s.outputToken.mint,
        amount: lamports,
        taker: event.walletAddress,
      );

      final swapTxBase64 = order['transaction'] as String?;
      final requestId = order['requestId'] as String?;
      if (swapTxBase64 == null || swapTxBase64.isEmpty || requestId == null) {
        throw Exception(order['errorMessage'] ?? order['error'] ?? 'Jupiter could not build this swap');
      }

      final signedBytes = await _signTransaction(base64Decode(swapTxBase64), keyPair);

      // Jupiter broadcasts and polls for landing itself, so there is no
      // sendTransaction here — handing it back is what requestId is for.
      final result = await _jupiter.execute(
        signedTransaction: base64Encode(signedBytes),
        requestId: requestId,
      );

      final status = result['status']?.toString();
      final signature = (result['signature'] ?? result['txid'] ?? result['transactionId'])?.toString();
      debugLog('[Swap] execute -> status=$status sig=$signature code=${result['code']}');

      if (status == 'Success' && signature != null) {
        emit(SwapSuccess(signature));
        return;
      }

      // Jupiter timing out on its own polling is not the same as the swap
      // failing — check the chain before telling the user it didn't happen.
      if (signature != null) {
        final outcome = await _txService.confirmSigned(
          signature: signature,
          blockhash: encoder.SignedTx.decode(base64Encode(signedBytes)).blockhash,
        );
        if (outcome.isConfirmed) {
          emit(SwapSuccess(signature));
          return;
        }
        emit(SwapError(outcome.error ?? 'The swap did not confirm.'));
        return;
      }

      throw Exception(result['error'] ?? 'Swap failed');
    } catch (e) {
      emit(SwapError('Swap failed: $e'));
    }
  }

  // Jupiter returns a v0 VersionedTransaction with a placeholder signature
  // slot. Layout: [compact-u16 sig count][sigs * 64 bytes][message]. We
  // sign the message and patch our signature into the first slot.
  Future<Uint8List> _signTransaction(
    Uint8List txBytes,
    solana.Ed25519HDKeyPair keyPair,
  ) async {
    int offset = 0;
    int sigCount = txBytes[offset++];
    if (sigCount >= 0x80) {
      sigCount = (sigCount & 0x7f) | (txBytes[offset++] << 7);
    }

    final messageBytes = txBytes.sublist(offset + (sigCount * 64));
    final signature = await keyPair.sign(messageBytes);

    final signed = Uint8List.fromList(txBytes);
    for (int i = 0; i < 64; i++) {
      signed[offset + i] = signature.bytes[i];
    }
    return signed;
  }
}
