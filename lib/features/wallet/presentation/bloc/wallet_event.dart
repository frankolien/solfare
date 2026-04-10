import 'package:equatable/equatable.dart';
import 'package:solfare/features/wallet/domain/entities/wallet.dart';

/// Events that can be dispatched to WalletBloc
/// Events represent user actions or system triggers
abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

/// Event to create a new wallet
class CreateWalletEvent extends WalletEvent {
  const CreateWalletEvent();
}

/// Event to save a wallet to secure storage
class SaveWalletEvent extends WalletEvent {
  final Wallet wallet;

  const SaveWalletEvent(this.wallet);

  @override
  List<Object?> get props => [wallet];
}

/// Event to check if a wallet exists
class CheckWalletExistsEvent extends WalletEvent {
  const CheckWalletExistsEvent();
}

/// Event to request airdrop (devnet/testnet only)
class RequestAirdropEvent extends WalletEvent {
  final String address;
  final int lamports; // Amount in lamports (default: 1 SOL = 1,000,000,000)

  const RequestAirdropEvent({
    required this.address,
    this.lamports = 1000000000, // 1 SOL
  });

  @override
  List<Object?> get props => [address, lamports];
}

/// Event to fetch wallet balance
class FetchBalanceEvent extends WalletEvent {
  final String address;

  const FetchBalanceEvent(this.address);

  @override
  List<Object?> get props => [address];
}

/// Event to reset wallet state
class ResetWalletEvent extends WalletEvent {
  const ResetWalletEvent();
}

/// Event to clear all wallet data from storage
class ClearWalletEvent extends WalletEvent {
  const ClearWalletEvent();
}

/// Event to fetch SOL price
class FetchSolPriceEvent extends WalletEvent {
  const FetchSolPriceEvent();
}

class LoadWalletAddressEvent extends WalletEvent {
  const LoadWalletAddressEvent();

}

class ImportWalletEvent extends WalletEvent {
  final String mnemonic;
  const ImportWalletEvent(this.mnemonic);

  @override
  List<Object?> get props => [mnemonic];
}

/// Event to fetch transaction history
class FetchTransactionsEvent extends WalletEvent {
  final String address;

  const FetchTransactionsEvent(this.address);
  

  @override
  List<Object?> get props => [address];
}
