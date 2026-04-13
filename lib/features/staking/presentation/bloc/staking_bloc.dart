import 'package:bip39/bip39.dart' as bip39;
import 'package:bloc/bloc.dart';
import 'package:ed25519_hd_key/ed25519_hd_key.dart';
import 'package:solana/solana.dart' as solana;
import 'package:solana/src/rpc/dto/account_data/stake_program/authorized.dart';
import 'package:solana/src/rpc/dto/latest_blockhash.dart';
import 'package:solfare/core/constant/solana_path.dart';
import 'package:solfare/features/staking/domain/entities/stake_account.dart';
import 'package:solfare/features/staking/domain/entities/validator_info.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_event.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_state.dart';
import 'package:solfare/features/wallet/data/datasource/solana_rpc_datasource.dart';
import 'package:solfare/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:solfare/features/wallet/data/datasource/wallet_local_datasource.dart';

class StakingBloc extends Bloc<StakingEvent, StakingState> {
  final SolanaRpcDataSource _rpcDataSource;
  final WalletRepositoryImpl _repository;

  StakingBloc({
    SolanaRpcDataSource? rpcDataSource,
    WalletRepositoryImpl? repository,
  })  : _rpcDataSource = rpcDataSource ?? SolanaRpcDataSourceImpl(),
        _repository = repository ??
            WalletRepositoryImpl(
              localDataSource: WalletLocalDataSourceImpl(),
            ),
        super(const StakingInitial()) {
    on<FetchStakeAccountsEvent>(_onFetchStakeAccounts);
    on<FetchValidatorsEvent>(_onFetchValidators);
    on<DelegateStakeEvent>(_onDelegateStake);
  }

  Future<void> _onFetchStakeAccounts(
    FetchStakeAccountsEvent event,
    Emitter<StakingState> emit,
  ) async {
    emit(const StakingLoading());
    try {
      final raw = await _rpcDataSource.getStakeAccounts(event.walletAddress);
      final accounts = raw.map((a) => StakeAccount(
            pubkey: a['pubkey'] as String,
            lamports: a['lamports'] as int,
            voterPubkey: a['voterPubkey'] as String?,
            state: _determineState(
              a['activationEpoch'] as int,
              a['deactivationEpoch'] as int,
            ),
            activationEpoch: a['activationEpoch'] as int,
            deactivationEpoch: a['deactivationEpoch'] as int,
          )).toList();
      emit(StakeAccountsFetched(accounts));
    } catch (e) {
      emit(StakingError(e.toString()));
    }
  }

  String _determineState(int activationEpoch, int deactivationEpoch) {
    // Max u64 means "not set"
    const maxEpoch = 9223372036854775807;
    if (deactivationEpoch != maxEpoch && deactivationEpoch != 0) {
      return 'deactivating';
    }
    if (activationEpoch == 0) return 'inactive';
    return 'activating';
  }

  Future<void> _onFetchValidators(
    FetchValidatorsEvent event,
    Emitter<StakingState> emit,
  ) async {
    emit(const StakingLoading());
    try {
      final raw = await _rpcDataSource.getVoteAccounts();
      final validators = raw.map((v) => ValidatorInfo(
            votePubkey: v['votePubkey'] as String,
            name: _validatorName(v['votePubkey'] as String),
            activatedStake: v['activatedStake'] as int,
            commission: (v['commission'] as int).toDouble(),
          )).toList();
      // Sort by stake descending
      validators.sort((a, b) => b.activatedStake.compareTo(a.activatedStake));
      emit(ValidatorsFetched(validators));
    } catch (e) {
      emit(StakingError(e.toString()));
    }
  }

  /// Well-known devnet/mainnet validators get friendly names
  String _validatorName(String votePubkey) {
    const knownValidators = {
      'CertusDeBmqN8ZawdkxK5kFGMwBXdudvWHYwtNgNhvLu': 'Certus One',
      'dv1ZAGvdsz5hHLwWXsVnM94hWf1pjbKVau1QVkaMJ92': 'Kiln devnet validator',
      'dv2eQHeP4RFUTqFAo2M5YLrc8sMpEyenKi3VoU741qY': 'Kiln devnet validator',
      'dv3qDFk1DTF36Z62bNvrCXe9sKATA6xvVy6A798xxAS': 'Kiln devnet validator',
      'dv4ACNkpYPcE3aKmYDqZm9G5EB3J4MRoeE7WNDRBVJB': 'Kiln devnet validator',
    };
    return knownValidators[votePubkey] ?? 'Validator ${votePubkey.substring(0, 4)}...${votePubkey.substring(votePubkey.length - 4)}';
  }

  Future<void> _onDelegateStake(
    DelegateStakeEvent event,
    Emitter<StakingState> emit,
  ) async {
    emit(const StakeDelegating());
    try {
      // 1. Get mnemonic and derive keypair
      final mnemonic = await _repository.getStoredMnemonic();
      if (mnemonic == null) {
        throw Exception('No wallet found. Please create or import a wallet first.');
      }

      final seed = bip39.mnemonicToSeed(mnemonic);
      final keyData = await ED25519_HD_KEY.derivePath(
        SolanaPath.defaultPath,
        seed,
      );
      final senderKeyPair = await solana.Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: keyData.key,
      );

      // 2. Generate a new keypair for the stake account
      final stakeAccountKeyPair = await solana.Ed25519HDKeyPair.random();

      // 3. Calculate lamports
      final lamports = (event.amountInSol * 1000000000).toInt();

      // 4. Get rent exemption for stake account (200 bytes)
      final rentExemption = await _rpcDataSource.getMinimumBalanceForRentExemption(200);

      print('[StakingBloc] lamports=$lamports, rentExemption=$rentExemption, total=${lamports + rentExemption}');
      print('[StakingBloc] sender=${senderKeyPair.address}');
      print('[StakingBloc] stakeAccount=${stakeAccountKeyPair.address}');
      print('[StakingBloc] validator=${event.validatorVoteAccount}');

      // 5. Get recent blockhash
      final blockhashData = await _rpcDataSource.getLatestBlockhash();
      final latestBlockhash = LatestBlockhash(
        blockhash: blockhashData['blockhash'] as String,
        lastValidBlockHeight: blockhashData['lastValidBlockHeight'] as int,
      );

      // 6. Build instructions: createAccount + initialize + delegateStake
      final createAndInitInstructions = solana.StakeInstruction.createAndInitializeAccount(
        fundingAccount: senderKeyPair.publicKey,
        newAccount: stakeAccountKeyPair.publicKey,
        authorized: Authorized(
          staker: senderKeyPair.address,
          withdrawer: senderKeyPair.address,
        ),
        lamports: lamports + rentExemption,
      );

      final delegateInstruction = solana.StakeInstruction.delegateStake(
        stake: stakeAccountKeyPair.publicKey,
        vote: solana.Ed25519HDPublicKey.fromBase58(event.validatorVoteAccount),
        config: solana.Ed25519HDPublicKey.fromBase58('StakeConfig11111111111111111111111111111111'),
        authority: senderKeyPair.publicKey,
      );

      // 7. Build message with all instructions
      final message = solana.Message(
        instructions: [...createAndInitInstructions, delegateInstruction],
      );

      // 8. Sign with both keys (sender funds the account, stake account is the new account)
      final signedTx = await solana.signTransaction(
        latestBlockhash,
        message,
        [senderKeyPair, stakeAccountKeyPair],
      );

      // 9. Send transaction
      final base64Tx = signedTx.encode();
      final signature = await _rpcDataSource.sendTransaction(base64Tx);

      print('[StakingBloc] DelegateStake SUCCESS: $signature');
      emit(StakeDelegated(
        signature: signature,
        amountInSol: event.amountInSol,
      ));
    } catch (e, stackTrace) {
      print('[StakingBloc] DelegateStake FAILED: $e');
      print('[StakingBloc] StackTrace: $stackTrace');
      emit(StakingError(e.toString()));
    }
  }
}
