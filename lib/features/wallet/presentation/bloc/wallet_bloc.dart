import 'package:bloc/bloc.dart';
import 'package:solfare/features/wallet/data/datasource/crypto_price_datasource.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';
import 'package:solfare/features/wallet/data/datasource/wallet_local_datasource.dart';
import 'package:solfare/features/wallet/data/repositories/wallet_repository_impl.dart';
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
  }

  Future<void> _onImportWallet(
    ImportWalletEvent event,
    Emitter<WalletState> emit,
  ) async {
    print('[BLoC] ImportWallet — mnemonic words: ${event.mnemonic.split(' ').length}');
    emit(const WalletLoading());
    try {
      final wallet = await _repository.importWallet(event.mnemonic);
      print('[BLoC] ImportWallet — success! Address: ${wallet.address}');
      emit(WalletCreated(wallet, true));
    } catch (e) {
      print('[BLoC] ImportWallet — FAILED: $e');
      emit(WalletError(e.toString()));
    }
  }

  Future<void> _onLoadWalletAddress(
    LoadWalletAddressEvent event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final address = await _repository.getSavedAddress();
      if (address != null && address.isNotEmpty) {
        emit(WalletAddressLoaded(address));
      } else {
        emit(const WalletError('No wallet address found'));
      }
    } catch (e) {
      emit(WalletError(e.toString()));
    }
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
      print('Failed to fetch SOL price: $e');
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
}
