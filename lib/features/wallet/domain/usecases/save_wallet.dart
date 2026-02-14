import 'package:solfare/features/wallet/domain/entities/wallet.dart';
import 'package:solfare/features/wallet/domain/repositories/wallet_repository.dart';

/// Use case: Persist wallet credentials to secure storage.
/// Called after the user has confirmed their recovery phrase.
class SaveWalletUseCase {
  final WalletRepository _repository;

  SaveWalletUseCase({required WalletRepository repository})
      : _repository = repository;

  Future<void> call(Wallet wallet) async {
    await _repository.saveWallet(wallet);
  }
}
