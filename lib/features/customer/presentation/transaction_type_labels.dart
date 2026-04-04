import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';

String transactionTypeLocalized(BuildContext context, String type) {
  final l10n = AppLocalizations.of(context)!;
  switch (type) {
    case 'cashback_earned':
      return l10n.txTypeCashbackEarnedShort;
    case 'purchase':
      return l10n.filterPurchase;
    case 'redemption':
      return l10n.filterRedemption;
    case 'subscription':
      return l10n.filterSubscription;
    case 'cashback_bonus':
    case 'referral_bonus':
    case 'streak_bonus':
    case 'birthday_bonus':
      return l10n.filterBonus;
    case 'manual_adjustment':
      return l10n.txTypeAdjustment;
    default:
      return type;
  }
}
