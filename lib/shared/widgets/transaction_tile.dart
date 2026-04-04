import 'package:flutter/material.dart';

import '../models/transaction_model.dart';

/// List tile for a single ledger entry — polish when history screen exists.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(transaction.id),
      subtitle: Text('${transaction.amount}'),
    );
  }
}
