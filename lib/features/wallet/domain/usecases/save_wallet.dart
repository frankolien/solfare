import 'package:solfare/features/wallet/domain/entities/wallet.dart';
import 'package:solfare/features/wallet/domain/repositories/wallet_repository.dart';

class SaveWalletUseCase {
  final WalletRepository _repository;

  SaveWalletUseCase({required WalletRepository repository})
      : _repository = repository;

  Future<void> call(Wallet wallet) async {
    await _repository.saveWallet(wallet);
  }
}
