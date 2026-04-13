import 'package:equatable/equatable.dart';

abstract class StakingEvent extends Equatable {
  const StakingEvent();

  @override
  List<Object?> get props => [];
}

class FetchStakeAccountsEvent extends StakingEvent {
  final String walletAddress;
  const FetchStakeAccountsEvent(this.walletAddress);
  @override
  List<Object?> get props => [walletAddress];
}

class FetchValidatorsEvent extends StakingEvent {
  const FetchValidatorsEvent();
}

class DelegateStakeEvent extends StakingEvent {
  final String validatorVoteAccount;
  final double amountInSol;
  const DelegateStakeEvent({
    required this.validatorVoteAccount,
    required this.amountInSol,
  });
  @override
  List<Object?> get props => [validatorVoteAccount, amountInSol];
}

class DeactivateStakeEvent extends StakingEvent {
  final String stakeAccountPubkey;
  const DeactivateStakeEvent(this.stakeAccountPubkey);
  @override
  List<Object?> get props => [stakeAccountPubkey];
}

class WithdrawStakeEvent extends StakingEvent {
  final String stakeAccountPubkey;
  final int lamports;
  const WithdrawStakeEvent({
    required this.stakeAccountPubkey,
    required this.lamports,
  });
  @override
  List<Object?> get props => [stakeAccountPubkey, lamports];
}
