import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_state.dart';
import 'package:solfare/features/wallet/domain/entities/spl_token.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';

void main() {
  const a = '2jBAqgtrrvteWarFeqko1nhRmhHoMU2gLxYHWRDaQPgB';
  const b = 'HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk';

  const token = SplToken(
    mint: 'J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn',
    name: 'Jito Staked SOL',
    symbol: 'JitoSOL',
    balance: 1,
    decimals: 9,
    priceUsd: 90,
    priceChange24h: 1,
  );

  test('the same list for two wallets is two different states', () {
    // Equatable drops a state equal to the current one. Without the address,
    // an empty list for wallet B looked identical to an empty list for wallet
    // A and was never emitted.
    expect(
      const TokensFetched([], address: a),
      isNot(const TokensFetched([], address: b)),
    );
    expect(
      const NftsFetched([], address: a),
      isNot(const NftsFetched([], address: b)),
    );
    expect(
      const StakeAccountsFetched([], address: a),
      isNot(const StakeAccountsFetched([], address: b)),
    );
  });

  test('a holding and an empty wallet are distinguishable', () {
    expect(
      const TokensFetched([token], address: a),
      isNot(const TokensFetched([], address: a)),
    );
  });

  test('an untagged state still compares, for callers that do not set it', () {
    expect(const TokensFetched([]), const TokensFetched([]));
  });
}
