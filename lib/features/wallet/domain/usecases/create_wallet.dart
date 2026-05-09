import 'package:solfare/features/wallet/domain/entities/wallet.dart';
import 'package:solfare/features/wallet/domain/repositories/wallet_repository.dart';

// Returns the wallet without persisting; the user has to confirm the
// recovery phrase first, after which the UI dispatches SaveWalletEvent.
class CreateWalletUseCase {
  final WalletRepository _repository;

  CreateWalletUseCase({required WalletRepository repository})
      : _repository = repository;

  Future<Wallet> call() async {
    return await _repository.createWallet();
  }
}
