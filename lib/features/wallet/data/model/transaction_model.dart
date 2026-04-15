import 'package:solfare/features/wallet/domain/entities/transactions.dart';

class TransactionModel extends Transaction {
  const TransactionModel({
    required super.amount,
    required super.transactionFee,
    required super.signature,
    required super.sender,
    required super.receiver,
    required super.timestamp,
    required super.status,
    super.kind,
    super.nft,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      amount: json['amount'],
      transactionFee: json['transactionFee'],
      signature: json['signature'],
      sender: json['sender'],
       receiver: json['receiver'], 
       timestamp: DateTime.parse(json['timestamp']),
        status: json['status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'transactionFee': transactionFee,
      'signature': signature,
      'sender': sender,
      'receiver': receiver,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }

}
