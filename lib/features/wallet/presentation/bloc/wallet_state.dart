import 'package:equatable/equatable.dart';
import 'package:solfare/features/wallet/domain/entities/wallet.dart';

/// States that WalletBloc can emit
/// States represent the current condition of the wallet feature
abstract class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

/// Initial state - no wallet operations have occurred
class WalletInitial extends WalletState {
  const WalletInitial();
}

/// Loading state - wallet operation is in progress
class WalletLoading extends WalletState {
  const WalletLoading();
}

/// Wallet created successfully
class WalletCreated extends WalletState {
  final Wallet wallet;

  const WalletCreated(this.wallet);

  @override
  List<Object?> get props => [wallet];
}

/// Wallet saved successfully
class WalletSaved extends WalletState {
  const WalletSaved();
}

/// Wallet exists check completed
class WalletExistsChecked extends WalletState {
  final bool exists;

  const WalletExistsChecked(this.exists);

  @override
  List<Object?> get props => [exists];
}

/// Error state - something went wrong
class WalletError extends WalletState {
  final String message;

  const WalletError(this.message);

  @override
  List<Object?> get props => [message];
}
