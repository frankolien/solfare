
class Transaction {
  final int amount;
  final int transactionFee;
  final String signature;
  final String sender;
  final String receiver;
  final DateTime timestamp;
  final String status;

  const Transaction({
    required this.amount,
    required this.transactionFee,
    required this.signature,
    required this.sender,
    required this.receiver,
    required this.timestamp,
    required this.status,
  });

}


