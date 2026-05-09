import 'package:solfare/features/wallet/domain/entities/wallet.dart';
import 'package:solfare/features/wallet/domain/repositories/wallet_repository.dart';

class ImportWalletUseCase {
  final WalletRepository _repository;

  ImportWalletUseCase({required WalletRepository repository})
      : _repository = repository;

  Future<Wallet> call(String mnemonic) async {
    return await _repository.importWallet(mnemonic);
  }
}
  