import 'package:solfare/features/wallet/domain/entities/wallet.dart';
import 'package:solfare/features/wallet/domain/repositories/wallet_repository.dart';

/// Use case: Create a brand new Solana wallet.
///
/// 1. Generates mnemonic + derives keypair
/// 2. Returns the wallet so the UI can show the recovery phrase
/// 3. Does NOT save automatically — let the user confirm the phrase first
class CreateWalletUseCase {
  final WalletRepository _repository;

  CreateWalletUseCase({required WalletRepository repository})
      : _repository = repository;

  Future<Wallet> call() async {
    return await _repository.createWallet();
  }
}
