import 'package:equatable/equatable.dart';
import 'package:solfare/features/staking/domain/entities/stake_account.dart';
import 'package:solfare/features/staking/domain/entities/validator_info.dart';

abstract class StakingState extends Equatable {
  const StakingState();
  @override
  List<Object?> get props => [];
}

class StakingInitial extends StakingState {
  const StakingInitial();
}

class StakingLoading extends StakingState {
  const StakingLoading();
}

class StakeAccountsFetched extends StakingState {
  final List<StakeAccount> accounts;
  const StakeAccountsFetched(this.accounts);
  @override
  List<Object?> get props => [accounts];
}

class ValidatorsFetched extends StakingState {
  final List<ValidatorInfo> validators;
  const ValidatorsFetched(this.validators);
  @override
  List<Object?> get props => [validators];
}

class StakeDelegating extends StakingState {
  const StakeDelegating();
}

class StakeDelegated extends StakingState {
  final String signature;
  final double amountInSol;
  const StakeDelegated({required this.signature, required this.amountInSol});
  @override
  List<Object?> get props => [signature, amountInSol];
}

class StakeDeactivating extends StakingState {
  const StakeDeactivating();
}

class StakeDeactivated extends StakingState {
  final String signature;
  const StakeDeactivated({required this.signature});
  @override
  List<Object?> get props => [signature];
}

class StakeWithdrawing extends StakingState {
  const StakeWithdrawing();
}

class StakeWithdrawn extends StakingState {
  final String signature;
  const StakeWithdrawn({required this.signature});
  @override
  List<Object?> get props => [signature];
}

class StakingError extends StakingState {
  final String message;
  const StakingError(this.message);
  @override
  List<Object?> get props => [message];
}
