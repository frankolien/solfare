import 'package:bloc/bloc.dart';
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
  final WalletRepositoryImpl _repository;
  final CreateWalletUseCase _createWallet;
  final SaveWalletUseCase _saveWallet;

  WalletBloc({
    WalletRepositoryImpl? repository,
  })  : _repository = repository ??
            WalletRepositoryImpl(
              localDataSource: WalletLocalDataSourceImpl(),
            ),
        _createWallet = CreateWalletUseCase(
          repository: repository ??
              WalletRepositoryImpl(
                localDataSource: WalletLocalDataSourceImpl(),
              ),
        ),
        _saveWallet = SaveWalletUseCase(
          repository: repository ??
              WalletRepositoryImpl(
                localDataSource: WalletLocalDataSourceImpl(),
              ),
        ),
        super(const WalletInitial()) {
    // Register event handlers
    // When CreateWalletEvent is dispatched, handle it with _onCreateWallet
    on<CreateWalletEvent>(_onCreateWallet);
    on<SaveWalletEvent>(_onSaveWallet);
    on<CheckWalletExistsEvent>(_onCheckWalletExists);
    on<ResetWalletEvent>(_onResetWallet);
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

      // Emit success state with wallet data
      emit(WalletCreated(wallet));
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
}
