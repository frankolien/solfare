import 'package:equatable/equatable.dart';

class StakeAccount extends Equatable {
  final String pubkey;
  final int lamports;
  final String? voterPubkey;
  final String state; // 'activating', 'active', 'deactivating', 'inactive'
  final int activationEpoch;
  final int deactivationEpoch;

  const StakeAccount({
    required this.pubkey,
    required this.lamports,
    this.voterPubkey,
    required this.state,
    this.activationEpoch = 0,
    this.deactivationEpoch = 0,
  });

  double get amountInSol => lamports / 1000000000;

  @override
  List<Object?> get props => [pubkey, lamports, voterPubkey, state];
}
