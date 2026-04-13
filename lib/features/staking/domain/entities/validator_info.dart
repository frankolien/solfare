import 'package:equatable/equatable.dart';

class ValidatorInfo extends Equatable {
  final String votePubkey;
  final String name;
  final String? iconUrl;
  final double apyPercent;
  final int activatedStake; // in lamports
  final double commission;

  const ValidatorInfo({
    required this.votePubkey,
    required this.name,
    this.iconUrl,
    this.apyPercent = 0.0,
    this.activatedStake = 0,
    this.commission = 0.0,
  });

  double get totalStakeInSol => activatedStake / 1000000000;

  @override
  List<Object?> get props => [votePubkey, name, apyPercent];
}
