import 'dart:async';
import 'dart:convert';

import 'package:bip39/bip39.dart' as bip39;
import 'package:bloc/bloc.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solana/solana.dart' as solana;
import 'package:solana/src/rpc/dto/latest_blockhash.dart';
import 'package:solfare/core/constant/solana_path.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/core/constant/network.dart';
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

/// BLoC (Business Logic Component) for wallet management
/// 
/// BLoC Pattern:
/// - Events: User actions (CreateWalletEvent, SaveWalletEvent, etc.)
/// - States: UI states (WalletLoading, WalletCreated, WalletError, etc.)
/// - Bloc: Processes events and emits states
/// 
/// Flow: Event → Bloc → State → UI
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
    // Now _repository is set, so we can reuse the SAME instance
    _createWallet = CreateWalletUseCase(repository: _repository);
    _saveWallet = SaveWalletUseCase(repository: _repository);

    // WS pushes balance changes — we forward them as a fetch event so the
    // normal HTTP path renders the state.
    _balanceWs = BalanceWsService(onChange: () {
      final addr = _watchedAddress;
      if (addr != null) add(FetchBalanceEvent(addr));
    });

    // Reconnect WS when the user switches network in settings.
    NetworkConstants.addListener(_onNetworkChanged);
    
    
    

    // Register event handlers
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

  /// Allows events to run concurrently instead of waiting in queue
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
      await prefs.setString(cacheKey, _encodeNfts(nfts));
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
    // Emit loading state - UI can show loading indicator
    emit(const WalletLoading());

    try {
      // Create wallet using use case
      final wallet = await _createWallet();
      final isImported = false;

      // Emit success state with wallet data
      emit(WalletCreated(wallet, isImported));
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
      emit(BalanceFetched(balance: balance, address: event.address));
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
      emit(SolPriceFetched(
        priceUsd: price,
        priceChange24h: priceChange24h,
      ));
    } catch (e) {
      // Don't emit error state for price fetch failures - just log it
      // Price is not critical for app functionality
      debugLog('Failed to fetch SOL price: $e');
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
      emit(TransactionsFetched(transactions));
    } catch (e) {
      emit(WalletError(e.toString()));
    }
  }

  /// Send SOL to another address
  Future<void> _onSendSol(
    SendSolEvent event,
    Emitter<WalletState> emit,
  ) async {
    emit(const SendingSol());
    List<int>? seed;
    List<int>? privateKeyBytes;
    try {
      // 1. Get stored mnemonic to derive the keypair
      final mnemonic = await _repository.getStoredMnemonic();
      if (mnemonic == null) {
        throw Exception('No wallet found. Please create or import a wallet first.');
      }

      // 2. Derive the keypair from mnemonic
      seed = bip39.mnemonicToSeed(mnemonic);
      final keyData = await ED25519_HD_KEY.derivePath(
        SolanaPath.defaultPath,
        seed,
      );
      privateKeyBytes = keyData.key;

      // 3. Create Solana keypair from private key
      final senderKeyPair = await solana.Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: privateKeyBytes,
      );

      debugLog('[BLoC] SendSol — from: ${senderKeyPair.address}');
      debugLog('[BLoC] SendSol — to: ${event.recipientAddress}');
      debugLog('[BLoC] SendSol — amount: ${event.amountInSol} SOL');

      // 4. Convert SOL to lamports
      final lamports = (event.amountInSol * 1000000000).toInt();

      // 5. Get recent blockhash
      final blockhashData = await _rpcDataSource.getLatestBlockhash();
      final latestBlockhash = LatestBlockhash(
        blockhash: blockhashData['blockhash'] as String,
        lastValidBlockHeight: blockhashData['lastValidBlockHeight'] as int,
      );

      // 6. Build the transfer instruction
      final instruction = solana.SystemInstruction.transfer(
        fundingAccount: senderKeyPair.publicKey,
        recipientAccount: solana.Ed25519HDPublicKey.fromBase58(event.recipientAddress),
        lamports: lamports,
      );

      // 7. Build the transaction message
      final message = solana.Message(
        instructions: [instruction],
      );

      // 8. Sign the transaction
      final signedTx = await solana.signTransaction(
        latestBlockhash,
        message,
        [senderKeyPair],
      );

      // 9. Encode to base64 and send
      final base64Tx = signedTx.encode();
      final signature = await _rpcDataSource.sendTransaction(base64Tx);

      debugLog('[BLoC] SendSol — SUCCESS! Signature: $signature');

      emit(SolSent(
        signature: signature,
        amountInSol: event.amountInSol,
        recipientAddress: event.recipientAddress,
      ));

      // Kick off a balance refetch once the tx has had a chance to confirm.
      // The WS will also push an update when the account finalises, but
      // polling here guarantees the UI updates even if the WS is offline.
      // Three attempts because devnet/mainnet confirmation timing varies:
      // most settle under 2s, some take 5-15s under load.
      final sender = senderKeyPair.address;
      for (final delay in [2, 6, 15]) {
        Future.delayed(Duration(seconds: delay), () {
          if (isClosed) return;
          debugLog('[BLoC] Post-send refetch at ${delay}s for $sender');
          add(FetchBalanceEvent(sender));
          if (delay == 2) add(FetchTransactionsEvent(sender));
        });
      }
    } catch (e) {
      debugLog('[BLoC] SendSol — FAILED: $e');
      emit(WalletError(e.toString()));
    } finally {
      // Best-effort scrubbing of the derived key + seed. Dart's GC can
      // copy buffers so this is not a guarantee, but it closes the window
      // during which a heap dump would find intact key material.
      _zeroBytes(privateKeyBytes);
      _zeroBytes(seed);
    }
  }

  void _zeroBytes(List<int>? bytes) {
    if (bytes == null) return;
    try {
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = 0;
      }
    } catch (_) {
      // List may be unmodifiable — nothing we can do.
    }
  }
}
