import 'dart:async';
import 'dart:convert';

import 'package:solfare/core/util/json.dart';
import 'package:solfare/core/solana/lamports.dart';
import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/encoder.dart' as encoder;
import 'package:solana/solana.dart' as solana;
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/security/app_lock.dart';
import 'package:solfare/core/solana/pay/pay_request.dart';
import 'package:solfare/core/solana/pay/pay_resolver.dart';
import 'package:solfare/core/solana/preview/preview_engine.dart';
import 'package:solfare/core/solana/preview/recipient_check.dart';
import 'package:solfare/core/solana/preview/tx_preview.dart';
import 'package:solfare/core/solana/token/mint_info.dart';
import 'package:solfare/core/solana/token/token_service.dart';
import 'package:solfare/core/solana/transaction_service.dart';
import 'package:solfare/core/solana/tx_outcome.dart';
import 'package:solfare/core/wallet/keyring.dart';
import 'package:solfare/core/widgets/widget_bridge.dart';
import 'package:solfare/features/wallet/data/datasource/balance_ws_service.dart';
import 'package:solfare/features/wallet/data/datasource/binance_price_ws_service.dart';
import 'package:solfare/features/wallet/data/datasource/crypto_price_datasource.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';
import 'package:solfare/features/wallet/data/datasource/wallet_local_datasource.dart';
import 'package:solfare/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:solfare/features/wallet/domain/entities/nft.dart';
import 'package:solfare/features/wallet/domain/entities/spl_token.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';
import 'package:solfare/features/wallet/domain/usecases/create_wallet.dart';
import 'package:solfare/features/wallet/domain/usecases/save_wallet.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  late final WalletRepositoryImpl _repository;
  late final CreateWalletUseCase _createWallet;
  late final SaveWalletUseCase _saveWallet;
  final SolanaRpcDataSource _rpcDataSource;
  final CryptoPriceDataSource _priceDataSource;
  late final BalanceWsService _balanceWs;
  late final BinancePriceWsService _priceWs;
  late final TransactionService _txService;
  late final PreviewEngine _previewEngine;
  late final RecipientCheck _recipientCheck;
  late final TokenService _tokenService;
  late final PayResolver _payResolver;

  // The instructions (or merchant payload) resolved for the payment now on
  // screen.
  List<encoder.Instruction>? _pendingPayInstructions;
  String? _pendingPayPayload;

  // Tracks the address the WS is currently watching so we can re-subscribe
  // after network switches / app resume without duplicate subscriptions.
  String? _watchedAddress;

  // CoinGecko is the cold-start snapshot + slow fallback heartbeat.
  Timer? _priceTimer;
  static const _priceRefreshInterval = Duration(minutes: 5);

  // Last-known SOL price + 24h change + lamports, cached so either side of the
  // widget push (price arrives / balance arrives) can fill in the other.
  double? _lastSolPriceUsd;
  double? _lastSolPriceChange;
  int? _lastLamports;

  WalletBloc({
    WalletRepositoryImpl? repository,
    SolanaRpcDataSource? rpcDataSource,
    CryptoPriceDataSource? priceDataSource,
  })  : _repository = repository ??
            WalletRepositoryImpl(
              localDataSource: WalletLocalDataSourceImpl(),
            ),
        _rpcDataSource = rpcDataSource ?? SolanaRpcDataSourceImpl(),
        _priceDataSource = priceDataSource ?? CryptoPriceDataSourceImpl(),
        super(const WalletInitial()) {
    _createWallet = CreateWalletUseCase(repository: _repository);
    _saveWallet = SaveWalletUseCase(repository: _repository);
    _txService = TransactionService(_rpcDataSource);
    _previewEngine = PreviewEngine(_rpcDataSource);
    _recipientCheck = RecipientCheck(_rpcDataSource);
    _tokenService = TokenService(_rpcDataSource);
    _payResolver = PayResolver(_tokenService);

    // WS push → fetch event so the normal HTTP path renders the state.
    _balanceWs = BalanceWsService(onChange: () {
      final addr = _watchedAddress;
      if (addr != null) add(FetchBalanceEvent(addr));
    });

    // Binance public WS pushes ticker frames ~1Hz.
    _priceWs = BinancePriceWsService(
      onTick: (priceUsd, change) {
        if (isClosed) return;
        add(LivePriceTickEvent(priceUsd, change));
      },
    );

    NetworkConstants.addListener(_onNetworkChanged);

    on<CreateWalletEvent>(_onCreateWallet);
    on<SaveWalletEvent>(_onSaveWallet);
    on<CheckWalletExistsEvent>(_onCheckWalletExists);
    on<RequestAirdropEvent>(_onRequestAirdrop);
    on<FetchBalanceEvent>(_onFetchBalance);
    on<ResetWalletEvent>(_onResetWallet);
    on<ClearWalletEvent>(_onClearWallet);
    on<FetchSolPriceEvent>(_onFetchSolPrice);
    on<LivePriceTickEvent>(_onLivePriceTick);
    on<LoadWalletAddressEvent>(_onLoadWalletAddress);
    on<ImportWalletEvent>(_onImportWallet);
    on<FetchTransactionsEvent>(_onFetchTransactions);
    on<PreviewSendEvent>(_onPreviewSend);
    on<SendSolEvent>(_onSendSol);
    on<ResolvePayEvent>(_onResolvePay);
    on<ExecutePayEvent>(_onExecutePay);
    on<PreviewTokenSendEvent>(_onPreviewTokenSend);
    on<SendTokenEvent>(_onSendToken);
    on<FetchNftsEvent>(_onFetchNfts, transformer: _concurrent());
    on<FetchTokensEvent>(_onFetchTokens, transformer: _concurrent());
    on<LoadAllWalletsEvent>(_onLoadAllWallets);
    on<SwitchWalletEvent>(_onSwitchWallet);
    on<AddWalletEvent>(_onAddWallet);
    on<RemoveWalletEvent>(_onRemoveWallet);
    on<UpdateWalletNameEvent>(_onUpdateWalletName, transformer: _concurrent());
    on<UpdateCardBackgroundEvent>(_onUpdateCardBackground, transformer: _concurrent());
    on<LoadWalletCustomizationEvent>(_onLoadWalletCustomization, transformer: _concurrent());
    on<NetworkChangedEvent>(_onNetworkChangedEvent);
  }

  // Default Bloc transformer is sequential.
  static EventTransformer<E> _concurrent<E>() {
    return (events, mapper) => events.asyncExpand(mapper);
  }

  Future<void> _onLoadWalletCustomization(
    LoadWalletCustomizationEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final active = await _repository.getActiveWallet();
      if (active != null) {
        emit(WalletCustomizationLoaded(
          walletName: active.name,
          cardBackground: active.cardBackground,
        ));
      } else {
        emit(const WalletCustomizationLoaded(
            walletName: 'Main Wallet', cardBackground: 'card_1.png'));
      }
    } catch (_) {
      emit(const WalletCustomizationLoaded(
          walletName: 'Main Wallet', cardBackground: 'card_1.png'));
    }
  }

  Future<void> _onUpdateWalletName(
    UpdateWalletNameEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final active = await _repository.getActiveWallet();
      if (active == null) return;
      await _repository.renameWallet(active.id, event.name);
      emit(WalletCustomizationLoaded(
        walletName: event.name,
        cardBackground: active.cardBackground,
      ));
      // Also refresh WalletsLoaded so the swipeable carousel picks up the new
      // name on inactive pages.
      final all = await _repository.getAllWallets();
      emit(WalletsLoaded(wallets: all, activeId: active.id));
    } catch (_) {}
  }

  Future<void> _onUpdateCardBackground(
    UpdateCardBackgroundEvent event,
    Emitter<WalletState> emit,
  ) async {
    debugLog('[BLOC] _onUpdateCardBackground ENTERED with: ${event.cardFileName}');
    try {
      final active = await _repository.getActiveWallet();
      if (active == null) return;
      await _repository.setWalletCardBackground(active.id, event.cardFileName);
      emit(WalletCustomizationLoaded(
        walletName: active.name,
        cardBackground: event.cardFileName,
      ));
      final all = await _repository.getAllWallets();
      emit(WalletsLoaded(wallets: all, activeId: active.id));
    } catch (e) {
      debugLog('[BLOC] _onUpdateCardBackground ERROR: $e');
    }
  }

  static const _nftsCachePrefix = 'cached_nfts_';

  Future<void> _onFetchNfts(FetchNftsEvent event, Emitter<WalletState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_nftsCachePrefix${event.address}';

    // Emit cached NFTs first (if any) so the UI paints instantly on restart.
    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson != null) {
      final cached = _decodeNfts(cachedJson);
      if (cached.isNotEmpty) emit(NftsFetched(cached));
    }

    try {
      final nfts = await _rpcDataSource.getNfts(event.address);
      // The cache write is fine — it's keyed by address.
      await prefs.setString(cacheKey, _encodeNfts(nfts));
      if (_watchedAddress != null && _watchedAddress != event.address) {
        return;
      }
      emit(NftsFetched(nfts));
    } catch (_) {
      // Keep whatever cached list we already emitted; only surface empty if
      // there was nothing cached either.
      if (cachedJson == null) emit(NftsFetched(const []));
    }
  }

  String _encodeNfts(List<Nft> nfts) => jsonEncode(nfts
      .map((n) => {
            'mint': n.mint,
            'name': n.name,
            'imageUrl': n.imageUrl,
            'collection': n.collection,
            'description': n.description,
          })
      .toList());

  List<Nft> _decodeNfts(String raw) {
    try {
      return [
        for (final entry in asJsonList(jsonDecode(raw)))
          if (asJsonMap(entry) case final e?)
            if (e.stringAt('mint') case final mint?)
              Nft(
                mint: mint,
                name: e.stringAt('name') ?? '',
                imageUrl: e.stringAt('imageUrl'),
                collection: e.stringAt('collection'),
                description: e.stringAt('description'),
              ),
      ];
    } catch (_) {
      return const [];
    }
  }

  static const _tokensCachePrefix = 'cached_tokens_';

  Future<void> _onFetchTokens(FetchTokensEvent event, Emitter<WalletState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_tokensCachePrefix${event.address}';

    final cachedJson = prefs.getString(cacheKey);
    if (cachedJson != null) {
      final cached = _decodeTokens(cachedJson);
      if (cached.isNotEmpty) emit(TokensFetched(cached));
    }

    try {
      final tokens = await _rpcDataSource.getTokens(event.address);
      await prefs.setString(cacheKey, _encodeTokens(tokens));
      if (_watchedAddress != null && _watchedAddress != event.address) {
        return;
      }
      emit(TokensFetched(tokens));
    } catch (_) {
      if (cachedJson == null) emit(const TokensFetched([]));
    }
  }

  String _encodeTokens(List<SplToken> tokens) => jsonEncode(tokens
      .map((t) => {
            'mint': t.mint,
            'name': t.name,
            'symbol': t.symbol,
            'imageUrl': t.imageUrl,
            'balance': t.balance,
            'decimals': t.decimals,
            'priceUsd': t.priceUsd,
            'priceChange24h': t.priceChange24h,
          })
      .toList());

  List<SplToken> _decodeTokens(String raw) {
    try {
      return [
        for (final entry in asJsonList(jsonDecode(raw)))
          if (asJsonMap(entry) case final e?)
            if (e.stringAt('mint') case final mint?)
              SplToken(
                mint: mint,
                name: e.stringAt('name') ?? '',
                symbol: e.stringAt('symbol') ?? '',
                imageUrl: e.stringAt('imageUrl'),
                balance: e.doubleAt('balance') ?? 0,
                decimals: e.intAt('decimals') ?? 0,
                priceUsd: e.doubleAt('priceUsd') ?? 0,
                priceChange24h: e.doubleAt('priceChange24h') ?? 0,
              ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _onImportWallet(
    ImportWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    debugLog('[BLoC] ImportWallet — mnemonic words: ${event.mnemonic.split(' ').length}');
    emit(const WalletLoading());
    try {
      final wallet = await _repository.importWallet(event.mnemonic);
      debugLog('[BLoC] ImportWallet — success! Address: ${wallet.address}');
      emit(WalletCreated(wallet, true));
    } catch (e) {
      debugLog('[BLoC] ImportWallet — FAILED: $e');
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onLoadWalletAddress(
    LoadWalletAddressEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final active = await _repository.getActiveWallet();
      if (active != null && active.address.isNotEmpty) {
        await _activateWallet(active, emit);
      } else {
        emit(const WalletError('No wallet address found'));
      }
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  // Shared path for "the active wallet is now X" — emits the address +
  // customization states, starts WS/polling, and refreshes the wallet list.
  Future<void> _activateWallet(
    WalletAccount wallet,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletAddressLoaded(wallet.address));
    _watchedAddress = wallet.address;
    unawaited(_balanceWs.watch(wallet.address));
    _startPricePolling();
    unawaited(_priceWs.start());
    emit(WalletCustomizationLoaded(
      walletName: wallet.name,
      cardBackground: wallet.cardBackground,
    ));
    // Surface the current list so the swipeable card UI (PR 2) can render.
    final all = await _repository.getAllWallets();
    emit(WalletsLoaded(wallets: all, activeId: wallet.id));
  }

  Future<void> _onLoadAllWallets(
    LoadAllWalletsEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final all = await _repository.getAllWallets();
      final active = await _repository.getActiveWallet();
      emit(WalletsLoaded(wallets: all, activeId: active?.id));
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onSwitchWallet(
    SwitchWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await _repository.setActiveWalletId(event.walletId);
      final active = await _repository.getActiveWallet();
      if (active == null) {
        emit(const WalletError('Wallet not found'));
        return;
      }
      // Tear down WS for the old wallet before pointing everything at the new
      // one so we don't briefly double-subscribe.
      await _balanceWs.stop();
      await _activateWallet(active, emit);
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onAddWallet(
    AddWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final account = await _repository.addWallet(event.mnemonic, name: event.name);
      await _balanceWs.stop();
      await _activateWallet(account, emit);
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onRemoveWallet(
    RemoveWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await _repository.removeWallet(event.walletId);
      final remaining = await _repository.getAllWallets();
      if (remaining.isEmpty) {
        // No wallets left — stop WS + polling, show cleared state so the router
        // sends the user back to onboarding.
        _watchedAddress = null;
        _stopPricePolling();
        await _balanceWs.stop();
        emit(const WalletsLoaded(wallets: [], activeId: null));
        emit(const WalletCleared());
        return;
      }
      final active = await _repository.getActiveWallet();
      if (active != null) {
        await _balanceWs.stop();
        await _activateWallet(active, emit);
      }
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  // Called when [NetworkConstants.setNetwork] runs.
  void _onNetworkChanged(SolanaNetwork _) {
    _balanceWs.reconnect();
    add(const NetworkChangedEvent());
  }

  // Clears cluster-scoped data (tokens, NFTs) and refetches everything for the
  // active wallet so the UI doesn't show holdings from the previous cluster
  // after a network switch.
  Future<void> _onNetworkChangedEvent(
    NetworkChangedEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const TokensFetched([]));
    emit(const NftsFetched([]));
    final address = _watchedAddress;
    if (address != null) {
      add(FetchBalanceEvent(address));
      add(FetchTokensEvent(address));
      add(FetchNftsEvent(address));
      add(FetchTransactionsEvent(address));
    }
  }

  void _startPricePolling() {
    if (_priceTimer?.isActive ?? false) return;
    // Fire once immediately, then on the interval.
    add(const FetchSolPriceEvent());
    _priceTimer = Timer.periodic(_priceRefreshInterval, (_) {
      add(const FetchSolPriceEvent());
    });
  }

  void _stopPricePolling() {
    _priceTimer?.cancel();
    _priceTimer = null;
  }

  /// Manually force a WS reconnect, e.g. when the app returns to foreground.
  void reconnectBalanceStream() {
    _balanceWs.reconnect();
  }

  @override
  Future<void> close() {
    NetworkConstants.removeListener(_onNetworkChanged);
    _stopPricePolling();
    _balanceWs.dispose();
    _priceWs.dispose();
    return super.close();
  }

  Future<void> _onCreateWallet(
    CreateWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());
    try {
      final wallet = await _createWallet();
      emit(WalletCreated(wallet, false));
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onSaveWallet(
    SaveWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());

    try {
      await _saveWallet(event.wallet);
      emit(const WalletSaved());
      // Re-activate so WS/price polling/customization target the newly-saved
      // wallet and the swipeable card list picks it up on the next build.
      final active = await _repository.getActiveWallet();
      if (active != null) {
        await _balanceWs.stop();
        await _activateWallet(active, emit);
      }
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onCheckWalletExists(
    CheckWalletExistsEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());

    try {
      final exists = await _repository.hasWallet();
      emit(WalletExistsChecked(exists));
    } catch (e) {
      debugLog('[Wallet] exists check failed: $e');
      emit(WalletStoreUnreadable('$e'));
    }
  }

  Future<void> _onRequestAirdrop(
    RequestAirdropEvent event,
    Emitter<WalletState> emit,
  ) async {
    // The faucet is devnet/testnet-only — never hit it on mainnet.
    if (NetworkConstants.current == SolanaNetwork.mainnet) {
      emit(const WalletError('Airdrops are only available on devnet or testnet.'));
      return;
    }

    emit(const WalletLoading());

    try {
      final signature = await _rpcDataSource.requestAirdrop(
        event.address,
        event.lamports,
      );
      emit(AirdropRequested(
        transactionSignature: signature,
        address: event.address,
      ));
      
      await Future.delayed(const Duration(seconds: 2)); // Wait for confirmation
      final balance = await _rpcDataSource.getBalance(event.address);
      emit(BalanceFetched(balance: balance, address: event.address));
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onFetchBalance(
    FetchBalanceEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());

    try {
      final balance = await _rpcDataSource.getBalance(event.address);
      // Drop the result if the user has switched wallets while this request was
      // in flight.
      if (_watchedAddress != null && _watchedAddress != event.address) {
        return;
      }
      emit(BalanceFetched(balance: balance, address: event.address));
      _lastLamports = balance;
      await _pushWalletWidget(force: true);
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  void _onResetWallet(
    ResetWalletEvent event,
    Emitter<WalletState> emit,
  ) {
    emit(const WalletInitial());
  }

  Future<void> _onClearWallet(
    ClearWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());

    try {
      _watchedAddress = null;
      _stopPricePolling();
      await _balanceWs.stop();
      await _repository.clearWallet();
      // The passcode went with it, so the lock has nothing left to guard —
      // without this the router would hold the user on an unlock screen for a
      // wallet that no longer exists.
      AppLock.instance.forget();
      emit(const WalletCleared());
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onFetchSolPrice(
    FetchSolPriceEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final price = await _priceDataSource.getSolPrice();
      final priceChange24h = await _priceDataSource.getSolPriceChange24h();
      _lastSolPriceUsd = price;
      _lastSolPriceChange = priceChange24h;
      emit(SolPriceFetched(
        priceUsd: price,
        priceChange24h: priceChange24h,
      ));
      await WidgetBridge.pushPrice(
        symbol: 'SOL',
        priceUsd: price,
        percentChange24h: priceChange24h,
        sparkline: const [],
      );
      // Fresh price → refresh the wallet widget too, in case the very first
      // balance fetch beat us here and was skipped for lack of a price.
      await _pushWalletWidget(force: true);
    } catch (e) {
      // Don't emit error state for price fetch failures - just log it Price is
      // not critical for app functionality
      debugLog('Failed to fetch SOL price: $e');
    }
  }

  // Live ticker from Binance — same emission shape as the polled fetch so the
  // UI doesn't care which source served the latest value.
  Future<void> _onLivePriceTick(
    LivePriceTickEvent event,
    Emitter<WalletState> emit,
  ) async {
    _lastSolPriceUsd = event.priceUsd;
    _lastSolPriceChange = event.percentChange24h;
    emit(SolPriceFetched(
      priceUsd: event.priceUsd,
      priceChange24h: event.percentChange24h,
    ));
    await WidgetBridge.pushPrice(
      symbol: 'SOL',
      priceUsd: event.priceUsd,
      percentChange24h: event.percentChange24h,
      sparkline: const [],
    );
    await _pushWalletWidget();
  }

  // Best-effort push to the iOS widget extension.
  DateTime? _lastWidgetPush;
  static const _widgetPushInterval = Duration(seconds: 30);

  Future<void> _pushWalletWidget({bool force = false}) async {
    final price = _lastSolPriceUsd;
    final lamports = _lastLamports;
    if (price == null || lamports == null) return;

    final now = DateTime.now();
    final last = _lastWidgetPush;
    if (!force && last != null && now.difference(last) < _widgetPushInterval) {
      return;
    }
    _lastWidgetPush = now;

    try {
      final active = await _repository.getActiveWallet();
      if (active == null) return;
      final balanceUsd = Lamports.toSol(lamports) * price;
      await WidgetBridge.pushWallet(
        walletName: active.name,
        balanceUsd: balanceUsd,
        percentChange24h: _lastSolPriceChange ?? 0,
      );
    } catch (e) {
      debugLog('Failed to push wallet widget: $e');
    }
  }

  Future<void> _onFetchTransactions(
    FetchTransactionsEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());
    try {
      final transactions = await _rpcDataSource.getTransactionHistory(event.address);
      if (_watchedAddress != null && _watchedAddress != event.address) {
        return;
      }
      emit(TransactionsFetched(transactions));
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onPreviewSend(
    PreviewSendEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const SendPreviewLoading());
    try {
      final mnemonic = await _repository.getStoredMnemonic();
      if (mnemonic == null) {
        emit(const SendPreviewReady(TxPreview.unverified('No wallet found.')));
        return;
      }
      final keyPair = await Keyring.keyPairFromMnemonic(mnemonic);

      final instruction = solana.SystemInstruction.transfer(
        fundingAccount: keyPair.publicKey,
        recipientAccount: solana.Ed25519HDPublicKey.fromBase58(event.recipientAddress),
        lamports: Lamports.fromSol(event.amountInSol),
      );

      // What the destination is cannot be read off the transaction — a transfer
      // to a mint looks exactly like a transfer to a person.
      final recipientFlag = await _recipientCheck.inspect(event.recipientAddress);

      final preview = await _previewEngine.preview(
        instructions: [instruction],
        signers: [keyPair],
        ownerAddress: keyPair.address,
        extraFlags: [if (recipientFlag != null) recipientFlag],
      );
      emit(SendPreviewReady(preview));
    } catch (e) {
      // A preview that cannot run must not block the send.
      debugLog('[BLoC] PreviewSend failed: $e');
      emit(const SendPreviewReady(
          TxPreview.unverified('Could not check this transaction.')));
    }
  }

  // Resolve a scanned Solana Pay URL into something approvable.
  Future<void> _onResolvePay(ResolvePayEvent event, Emitter<WalletState> emit) async {
    emit(const PayResolving());
    _pendingPayInstructions = null;
    _pendingPayPayload = null;

    try {
      final request = PayResolver.parse(event.url);
      if (request == null) {
        emit(const PayFailed('That code is not a Solana Pay request.'));
        return;
      }

      final keyPair = await _keyPair();
      PayMerchant? merchant;
      TxPreview preview;

      switch (request) {
        case PayTransferRequest():
          final instructions = await _payResolver.buildTransfer(
            request: request,
            payer: keyPair.address,
          );
          _pendingPayInstructions = instructions;
          preview = await _previewEngine.preview(
            instructions: instructions,
            signers: [keyPair],
            ownerAddress: keyPair.address,
          );

        case PayTransactionRequest():
          // Ask who they are before asking for anything to sign, so the origin
          // is on screen before the payload is even fetched.
          merchant = await _payResolver.fetchMerchant(request);
          final payload = await _payResolver.fetchTransaction(
            request: request,
            account: keyPair.address,
          );
          _pendingPayPayload = payload;
          preview = await _previewEngine.previewSigned(
            base64Tx: payload,
            ownerAddress: keyPair.address,
          );
      }

      emit(PayReady(request: request, merchant: merchant, preview: preview));
    } on PayRequestException catch (e) {
      emit(PayFailed(e.message));
    } on TokenTransferException catch (e) {
      emit(PayFailed(e.message));
    } catch (e) {
      debugLog('[BLoC] ResolvePay failed: $e');
      emit(const PayFailed('That payment could not be prepared.'));
    }
  }

  Future<void> _onExecutePay(ExecutePayEvent event, Emitter<WalletState> emit) async {
    final instructions = _pendingPayInstructions;
    final payload = _pendingPayPayload;
    if (instructions == null && payload == null) return;

    emit(const SendingSol());
    try {
      final keyPair = await _keyPair();

      final outcome = payload != null
          ? await _txService.signAndSendPayload(base64Tx: payload, signer: keyPair)
          : await _txService.sendAndConfirm(
              instructions: instructions!,
              signers: [keyPair],
              onPhase: (phase) {
                if (!isClosed) emit(SendingSol(phase: phase));
              },
            );

      _pendingPayInstructions = null;
      _pendingPayPayload = null;

      if (!outcome.isConfirmed) {
        emit(SolSendFailed(
          message: outcome.error ?? 'The payment did not confirm.',
          signature: outcome.signature,
          expired: outcome.provenNotToHaveLanded,
        ));
        return;
      }

      emit(SolSent(
        signature: outcome.signature,
        amountInSol: 0,
        recipientAddress: '',
      ));

      add(FetchBalanceEvent(keyPair.address));
      add(FetchTokensEvent(keyPair.address));
    } catch (e) {
      debugLog('[BLoC] ExecutePay failed: $e');
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onPreviewTokenSend(
    PreviewTokenSendEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const SendPreviewLoading());
    try {
      final keyPair = await _keyPair();
      final mint = await _tokenService.mintInfo(event.mint);
      final instructions = await _tokenService.buildTransfer(
        mint: mint,
        owner: keyPair.address,
        recipient: event.recipientAddress,
        amount: _baseUnits(event.amount, mint.decimals),
      );

      final recipientFlag = await _recipientCheck.inspect(event.recipientAddress);

      final preview = await _previewEngine.preview(
        instructions: instructions,
        signers: [keyPair],
        ownerAddress: keyPair.address,
        symbols: {event.mint: ''},
        extraFlags: [
          if (recipientFlag != null) recipientFlag,
          ..._tokenSendNotes(mint, instructions, event.amount),
        ],
      );
      emit(SendPreviewReady(preview));
    } on TokenTransferException catch (e) {
      // A mint that cannot be sent is a fact, not a network hiccup.
      emit(SendPreviewReady(TxPreview.blocked(e.message)));
    } catch (e) {
      debugLog('[BLoC] PreviewTokenSend failed: $e');
      emit(const SendPreviewReady(
          TxPreview.unverified('Could not check this transaction.')));
    }
  }

  Future<void> _onSendToken(
    SendTokenEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const SendingSol());
    try {
      final keyPair = await _keyPair();
      final mint = await _tokenService.mintInfo(event.mint);
      final instructions = await _tokenService.buildTransfer(
        mint: mint,
        owner: keyPair.address,
        recipient: event.recipientAddress,
        amount: _baseUnits(event.amount, mint.decimals),
      );

      final outcome = await _txService.sendAndConfirm(
        instructions: instructions,
        signers: [keyPair],
        onPhase: (phase) {
          if (!isClosed) emit(SendingSol(phase: phase));
        },
      );

      if (!outcome.isConfirmed) {
        emit(SolSendFailed(
          message: outcome.error ?? 'The transfer did not confirm.',
          signature: outcome.signature,
          expired: outcome.provenNotToHaveLanded,
        ));
        return;
      }

      emit(SolSent(
        signature: outcome.signature,
        amountInSol: event.amount,
        recipientAddress: event.recipientAddress,
        symbol: event.symbol,
      ));

      add(FetchTokensEvent(keyPair.address));
      add(FetchTransactionsEvent(keyPair.address));
    } on TokenTransferException catch (e) {
      emit(WalletError(e.message));
    } on TxSimulationException catch (e) {
      emit(WalletError(e.message));
    } catch (e) {
      debugLog('[BLoC] SendToken failed: $e');
      emit(WalletError(e.toString()));
    }
  }

  // Things the balance deltas cannot say for themselves.
  List<RiskFlag> _tokenSendNotes(
    MintInfo mint,
    List<encoder.Instruction> instructions,
    double amount,
  ) {
    final notes = <RiskFlag>[];

    final fee = mint.transferFee;
    if (fee != null) {
      final base = _baseUnits(amount, mint.decimals);
      final net = fee.netOf(base);
      var divisor = 1.0;
      for (var i = 0; i < mint.decimals; i++) {
        divisor *= 10;
      }
      notes.add(RiskFlag(
        severity: RiskSeverity.info,
        title: 'This token charges a transfer fee',
        detail: '${fee.percent}% is withheld, so they receive '
            '${(net / divisor).toStringAsFixed(mint.decimals > 6 ? 6 : mint.decimals)} '
            'of the $amount you send.',
      ));
    }

    final createsAccount = instructions.any(
      (i) => i.programId.toBase58() == 'ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL',
    );
    if (createsAccount) {
      notes.add(const RiskFlag(
        severity: RiskSeverity.info,
        title: 'They have no account for this token yet',
        detail: 'You pay a one-off rent deposit to open one for them. It is '
            'part of the SOL leaving below, and they can reclaim it by '
            'closing the account.',
      ));
    }

    return notes;
  }

  Future<solana.Ed25519HDKeyPair> _keyPair() async {
    final mnemonic = await _repository.getStoredMnemonic();
    if (mnemonic == null) {
      throw Exception('No wallet found. Please create or import a wallet first.');
    }
    return Keyring.keyPairFromMnemonic(mnemonic);
  }

  int _baseUnits(double amount, int decimals) {
    var factor = 1.0;
    for (var i = 0; i < decimals; i++) {
      factor *= 10;
    }
    return (amount * factor).round();
  }

  Future<void> _onSendSol(
    SendSolEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const SendingSol());
    try {
      final mnemonic = await _repository.getStoredMnemonic();
      if (mnemonic == null) {
        throw Exception('No wallet found. Please create or import a wallet first.');
      }
      final senderKeyPair = await Keyring.keyPairFromMnemonic(mnemonic);

      final lamports = Lamports.fromSol(event.amountInSol);

      final instruction = solana.SystemInstruction.transfer(
        fundingAccount: senderKeyPair.publicKey,
        recipientAccount: solana.Ed25519HDPublicKey.fromBase58(event.recipientAddress),
        lamports: lamports,
      );

      final outcome = await _txService.sendAndConfirm(
        instructions: [instruction],
        signers: [senderKeyPair],
        onPhase: (phase) {
          if (!isClosed) emit(SendingSol(phase: phase));
        },
      );

      if (!outcome.isConfirmed) {
        debugLog('[BLoC] SendSol not confirmed: $outcome');
        emit(SolSendFailed(
          message: outcome.error ?? 'The transaction did not confirm.',
          signature: outcome.signature,
          // Expired means it never executed, which reads differently to a user
          // than "failed".
          expired: outcome.provenNotToHaveLanded,
        ));
        return;
      }

      emit(SolSent(
        signature: outcome.signature,
        amountInSol: event.amountInSol,
        recipientAddress: event.recipientAddress,
      ));

      // Settled at `confirmed` by the time we get here, so one refresh is
      // enough — the old 2/6/15s ladder covered for reporting success early.
      final sender = senderKeyPair.address;
      add(FetchBalanceEvent(sender));
      add(FetchTransactionsEvent(sender));
    } on TxSimulationException catch (e) {
      // Rejected before signing — nothing broadcast, nothing paid.
      debugLog('[BLoC] SendSol simulation rejected: ${e.message}');
      emit(WalletError(e.message));
    } catch (e) {
      debugLog('[BLoC] SendSol failed: $e');
      emit(WalletError(e.toString()));
    }
  }
}
