import 'package:flutter/material.dart';

/// Displays cashback vs subscription balances — UI to be designed with screens.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.cashbackBalance,
    required this.subscriptionBalance,
  });

  final double cashbackBalance;
  final double subscriptionBalance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Cashback: $cashbackBalance'),
            Text('Subscription: $subscriptionBalance'),
          ],
        ),
      ),
    );
  }
}
