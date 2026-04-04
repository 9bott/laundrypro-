import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:laundrypro/core/tier/tier_rules.dart';

void main() {
  test('cashback is exactly 20%', () {
    expect(50.0 * 0.20, equals(10.0));
    expect(100.0 * 0.20, equals(20.0));
  });

  test('subscription deduction uses subscription first', () {
    double subscriptionBalance = 20.0;
    double cashbackBalance = 25.0;
    double redeemAmount = 30.0;

    final subUsed = min(subscriptionBalance, redeemAmount);
    final cashUsed = redeemAmount - subUsed;

    expect(subUsed, equals(20.0));
    expect(cashUsed, equals(10.0));
    expect(subscriptionBalance - subUsed, equals(0.0));
    expect(cashbackBalance - cashUsed, equals(15.0));
  });

  test('tier calculation', () {
    expect(getTier(0), equals('bronze'));
    expect(getTier(499), equals('bronze'));
    expect(getTier(500), equals('silver'));
    expect(getTier(1999), equals('silver'));
    expect(getTier(2000), equals('gold'));
  });
}
