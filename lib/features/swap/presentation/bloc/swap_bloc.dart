import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:solana/solana.dart' as solana;
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/features/swap/data/datasource/jupiter_datasource.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_event.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_state.dart';

class SwapBloc extends Bloc<SwapEvent, SwapState> {
  late final JupiterDataSource _jupiter;
  final _storage = const FlutterSecureStorage();

  Map<String, dynamic>? _lastQuoteResponse;

  SwapBloc({JupiterDataSource? jupiter}) : super(const SwapInitial()) {
    _jupiter = jupiter ?? JupiterDataSource();

    on<LoadTokenListEvent>(_onLoadTokens);
    on<SelectInputTokenEvent>(_onSelectInput);
    on<SelectOutputTokenEvent>(_onSelectOutput);
    on<UpdateInputAmountEvent>(_onUpdateAmount);
    on<FetchQuoteEvent>(_onFetchQuote);
    on<ExecuteSwapEvent>(_onExecuteSwap);
    on<FlipTokensEvent>(_onFlipTokens);
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
      emit(s.copyWith(inputToken: event.token, outputAmount: null, rate: null));
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

        _lastQuoteResponse = quoteData;

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
      ));
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

      _lastQuoteResponse = quoteData;

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
    if (_lastQuoteResponse == null) return;

    emit(const SwapExecuting());

    try {
      // 1. Get serialized transaction from Jupiter
      final swapTxBase64 = await _jupiter.executeSwap(
        quoteResponse: _lastQuoteResponse!,
        userPublicKey: event.walletAddress,
      );

      // 2. Derive keypair from stored mnemonic
      final mnemonic = await _storage.read(key: 'wallet_mnemonic');
      if (mnemonic == null) throw Exception('No wallet found');

      final seed = bip39.mnemonicToSeed(mnemonic);
      final derivedKey = await ED25519_HD_KEY.derivePath("m/44'/501'/0'/0'", seed);
      final keyPair = await solana.Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: derivedKey.key,
      );

      // 3. Decode the versioned transaction, sign it, and send
      final txBytes = base64Decode(swapTxBase64);
      final signedBytes = await _signTransaction(txBytes, keyPair);

      // 4. Send via RPC
      final rpcUrl = NetworkConstants.solanaUrl;
      final response = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'sendTransaction',
          'params': [
            base64Encode(signedBytes),
            {'encoding': 'base64', 'preflightCommitment': 'confirmed'},
          ],
        }),
      );

      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        throw Exception(data['error']['message'] ?? 'Transaction failed');
      }

      final txId = data['result'] as String;
      emit(SwapSuccess(txId));
    } catch (e) {
      emit(SwapError('Swap failed: $e'));
    }
  }

  /// Sign a versioned transaction (v0) with the keypair
  /// Jupiter returns VersionedTransaction — we need to insert our signature
  Future<Uint8List> _signTransaction(
    Uint8List txBytes,
    solana.Ed25519HDKeyPair keyPair,
  ) async {
    // Versioned transaction layout:
    // [signature_count] [signatures...] [message...]
    // We need to sign the message part and replace the first signature

    // Read signature count (compact-u16)
    int offset = 0;
    int sigCount = txBytes[offset];
    offset += 1;
    if (sigCount >= 0x80) {
      // multi-byte compact-u16 — rare but handle it
      sigCount = (sigCount & 0x7f) | (txBytes[offset] << 7);
      offset += 1;
    }

    // The message starts after all signatures (each 64 bytes)
    final messageOffset = offset + (sigCount * 64);
    final messageBytes = txBytes.sublist(messageOffset);

    // Sign the message
    final signature = await keyPair.sign(messageBytes);

    // Replace the first signature in the transaction
    final signed = Uint8List.fromList(txBytes);
    final sigBytes = signature.bytes;
    for (int i = 0; i < 64; i++) {
      signed[offset + i] = sigBytes[i];
    }

    return signed;
  }
}
