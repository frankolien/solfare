import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart' as solana;
import 'package:solana/src/rpc/dto/latest_blockhash.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/wallet/keyring.dart';
import 'package:solfare/core/widgets/widget_bridge.dart';
import 'package:solfare/features/wallet/data/datasource/balance_ws_service.dart';
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

  // Tracks the address the WS is currently watching so we can re-subscribe
  // after network switches / app resume without duplicate subscriptions.
  String? _watchedAddress;

  // Periodic refresh of the SOL price. CoinGecko's /simple/price is cheap and
  // CoinGeckoClient throttles + dedupes — 30s cadence keeps the price card
  // feeling live without hammering the rate limit.
  Timer? _priceTimer;
  static const _priceRefreshInterval = Duration(seconds: 30);

  // Last-known SOL price + 24h change + lamports, cached so either side of
  // the widget push (price arrives / balance arrives) can fill in the other.
  // Without the lamports cache, a balance-fetch that beats the first
  // price-fetch is dropped on the floor and the widget shows preview data
  // until the *next* balance change — which can be hours.
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

    // WS push → fetch event so the normal HTTP path renders the state.
    _balanceWs = BalanceWsService(onChange: () {
      final addr = _watchedAddress;
      if (addr != null) add(FetchBalanceEvent(addr));
    });

    NetworkConstants.addListener(_onNetworkChanged);

    on<CreateWalletEvent>(_onCreateWallet);
    on<SaveWalletEvent>(_onSaveWallet);
    on<CheckWalletExistsEvent>(_onCheckWalletExists);
    on<RequestAirdropEvent>(_onRequestAirdrop);
    on<FetchBalanceEvent>(_onFetchBalance);
    on<ResetWalletEvent>(_onResetWallet);
    on<ClearWalletEvent>(_onClearWallet);
    on<FetchSolPriceEvent>(_onFetchSolPrice);
    on<LoadWalletAddressEvent>(_onLoadWalletAddress);
    on<ImportWalletEvent>(_onImportWallet);
    on<FetchTransactionsEvent>(_onFetchTransactions);
    on<SendSolEvent>(_onSendSol);
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

  // Default Bloc transformer is sequential. Reads we want to run in
  // parallel (token/NFT/customisation) use this instead.
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
      // Also refresh WalletsLoaded so the swipeable carousel picks up the
      // new name on inactive pages.
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
      // The cache write is fine — it's keyed by address. But emitting into
      // the bloc would leak this wallet's NFTs into the active wallet's UI
      // if the user switched mid-flight.
      await prefs.setString(cacheKey, _encodeNfts(nfts));
      if (_watchedAddress != null && _watchedAddress != event.address) {
        return;
      }
      emit(NftsFetched(nfts));
    } catch (_) {
      // Keep whatever cached list we already emitted; only surface empty
      // if there was nothing cached either.
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
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Nft(
                mint: e['mint'] as String,
                name: e['name'] as String,
                imageUrl: e['imageUrl'] as String?,
                collection: e['collection'] as String?,
                description: e['description'] as String?,
              ))
          .toList();
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
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => SplToken(
                mint: e['mint'] as String,
                name: e['name'] as String,
                symbol: e['symbol'] as String? ?? '',
                imageUrl: e['imageUrl'] as String?,
                balance: (e['balance'] as num).toDouble(),
                decimals: e['decimals'] as int? ?? 0,
                priceUsd: (e['priceUsd'] as num?)?.toDouble() ?? 0,
                priceChange24h: (e['priceChange24h'] as num?)?.toDouble() ?? 0,
              ))
          .toList();
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

  /// Shared path for "the active wallet is now X" — emits the address +
  /// customization states, starts WS/polling, and refreshes the wallet list.
  Future<void> _activateWallet(
    WalletAccount wallet,
    Emitter<WalletState> emit,
  ) async {
    emit(WalletAddressLoaded(wallet.address));
    _watchedAddress = wallet.address;
    _balanceWs.watch(wallet.address);
    _startPricePolling();
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
      // Tear down WS for the old wallet before pointing everything at the
      // new one so we don't briefly double-subscribe.
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
        // No wallets left — stop WS + polling, show cleared state so the
        // router sends the user back to onboarding.
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

  /// Called when [NetworkConstants.setNetwork] runs. Reconnects the WS to
  /// the new cluster AND refetches cluster-scoped data (balance, tokens,
  /// NFTs, transactions) for the active wallet — otherwise the UI keeps
  /// showing stale holdings from the previous network until the user
  /// manually refreshes.
  void _onNetworkChanged(SolanaNetwork _) {
    _balanceWs.reconnect();
    add(const NetworkChangedEvent());
  }

  /// Clears cluster-scoped data (tokens, NFTs) and refetches everything
  /// for the active wallet so the UI doesn't show holdings from the
  /// previous cluster after a network switch.
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

  /// Begin periodic SOL price refresh. Idempotent — calling twice won't
  /// spawn duplicate timers.
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
    return super.close();
  }

  /// Handle wallet creation event
  Future<void> _onCreateWallet(
    CreateWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());
    try {
      final wallet = await _createWallet();
      emit(WalletCreated(wallet, false));
    } catch (e) {
      // Emit error state if something goes wrong
      emit(WalletError(e.toString()));
    }
  }

  /// Handle wallet save event
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

  /// Handle wallet existence check
  Future<void> _onCheckWalletExists(
    CheckWalletExistsEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());

    try {
      final exists = await _repository.hasWallet();
      emit(WalletExistsChecked(exists));
    } catch (e) {
      // If check fails (e.g., corrupted data), default to no wallet
      // This is safer than blocking the user
      emit(const WalletExistsChecked(false));
    }
  }

  /// Handle airdrop request
  Future<void> _onRequestAirdrop(
    RequestAirdropEvent event,
    Emitter<WalletState> emit,
  ) async {
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
      
      // After airdrop, fetch the updated balance
      await Future.delayed(const Duration(seconds: 2)); // Wait for confirmation
      final balance = await _rpcDataSource.getBalance(event.address);
      emit(BalanceFetched(balance: balance, address: event.address));
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  /// Handle balance fetch
  Future<void> _onFetchBalance(
    FetchBalanceEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const WalletLoading());

    try {
      final balance = await _rpcDataSource.getBalance(event.address);
      // Drop the result if the user has switched wallets while this request
      // was in flight. Otherwise the previous wallet's balance lands ~10s
      // after the switch and overwrites the active wallet's display — a
      // serious UI confusion (and security) bug.
      if (_watchedAddress != null && _watchedAddress != event.address) {
        return;
      }
      emit(BalanceFetched(balance: balance, address: event.address));
      _lastLamports = balance;
      _pushWalletWidget();
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  /// Reset wallet state to initial
  void _onResetWallet(
    ResetWalletEvent event,
    Emitter<WalletState> emit,
  ) {
    emit(const WalletInitial());
  }

  /// Clear all wallet data from storage
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
      emit(const WalletCleared());
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  /// Fetch SOL price from API
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
      WidgetBridge.pushPrice(
        symbol: 'SOL',
        priceUsd: price,
        percentChange24h: priceChange24h,
        sparkline: const [],
      );
      // Fresh price → refresh the wallet widget too, in case the very first
      // balance fetch beat us here and was skipped for lack of a price.
      _pushWalletWidget();
    } catch (e) {
      // Don't emit error state for price fetch failures - just log it
      // Price is not critical for app functionality
      debugLog('Failed to fetch SOL price: $e');
    }
  }

  // Best-effort push to the iOS widget extension. Skipped silently on
  // Android / when we don't yet have both a price and a lamports figure to
  // compose the USD value from.
  Future<void> _pushWalletWidget() async {
    final price = _lastSolPriceUsd;
    final lamports = _lastLamports;
    if (price == null || lamports == null) return;
    try {
      final active = await _repository.getActiveWallet();
      if (active == null) return;
      final balanceUsd = (lamports / 1000000000) * price;
      await WidgetBridge.pushWallet(
        walletName: active.name,
        balanceUsd: balanceUsd,
        percentChange24h: _lastSolPriceChange ?? 0,
      );
    } catch (e) {
      debugLog('Failed to push wallet widget: $e');
    }
  }

  /// Fetch transaction history
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

      final lamports = (event.amountInSol * 1000000000).toInt();

      final blockhashData = await _rpcDataSource.getLatestBlockhash();
      final latestBlockhash = LatestBlockhash(
        blockhash: blockhashData['blockhash'] as String,
        lastValidBlockHeight: blockhashData['lastValidBlockHeight'] as int,
      );

      final instruction = solana.SystemInstruction.transfer(
        fundingAccount: senderKeyPair.publicKey,
        recipientAccount: solana.Ed25519HDPublicKey.fromBase58(event.recipientAddress),
        lamports: lamports,
      );

      final signedTx = await solana.signTransaction(
        latestBlockhash,
        solana.Message(instructions: [instruction]),
        [senderKeyPair],
      );

      final signature = await _rpcDataSource.sendTransaction(signedTx.encode());

      emit(SolSent(
        signature: signature,
        amountInSol: event.amountInSol,
        recipientAddress: event.recipientAddress,
      ));

      // Polling fallback in case the WS push is delayed or offline.
      // Devnet usually settles under 2s, mainnet sometimes 5-15s under load.
      final sender = senderKeyPair.address;
      for (final delay in [2, 6, 15]) {
        Future.delayed(Duration(seconds: delay), () {
          if (isClosed) return;
          add(FetchBalanceEvent(sender));
          if (delay == 2) add(FetchTransactionsEvent(sender));
        });
      }
    } catch (e) {
      debugLog('[BLoC] SendSol failed: $e');
      emit(WalletError(e.toString()));
    }
  }
}
