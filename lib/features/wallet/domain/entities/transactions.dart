import 'package:solfare/features/wallet/domain/entities/nft.dart';

enum TransactionKind { sol, nft }

class Transaction {
  final int amount;
  final int transactionFee;
  final String signature;
  final String sender;
  final String receiver;
  final DateTime timestamp;
  final String status;
  final TransactionKind kind;
  final Nft? nft;

  const Transaction({
    required this.amount,
    required this.transactionFee,
    required this.signature,
    required this.sender,
    required this.receiver,
    required this.timestamp,
    required this.status,
    this.kind = TransactionKind.sol,
    this.nft,
  });

}


