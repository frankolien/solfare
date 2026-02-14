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

/// Event to reset wallet state
class ResetWalletEvent extends WalletEvent {
  const ResetWalletEvent();
}
