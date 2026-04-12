import '../../core/constants/supabase_constants.dart';
import 'model_parsing.dart';

/// Row in `subscription_plans`: pay [price], credit [credit] to subscription balance.
class SubscriptionPlanModel {
  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.price,
    required this.credit,
    this.bonusPercentage,
    required this.isActive,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String nameAr;
  final double price;
  final double credit;
  final double? bonusPercentage;
  final bool isActive;
  final int sortOrder;

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json[kSubscriptionPlansId]! as String,
      name: json[kSubscriptionPlansName]! as String,
      nameAr: json[kSubscriptionPlansNameAr]! as String,
      price: modelParseDouble(json[kSubscriptionPlansPrice]),
      credit: modelParseDouble(json[kSubscriptionPlansCredit]),
      bonusPercentage:
          json[kSubscriptionPlansBonusPercentage] != null
              ? modelParseDouble(json[kSubscriptionPlansBonusPercentage])
              : null,
      isActive: modelParseBool(json[kSubscriptionPlansIsActive], true),
      sortOrder: modelParseInt(json[kSubscriptionPlansSortOrder]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      kSubscriptionPlansId: id,
      kSubscriptionPlansName: name,
      kSubscriptionPlansNameAr: nameAr,
      kSubscriptionPlansPrice: price,
      kSubscriptionPlansCredit: credit,
      kSubscriptionPlansBonusPercentage: bonusPercentage,
      kSubscriptionPlansIsActive: isActive,
      kSubscriptionPlansSortOrder: sortOrder,
    };
  }

  SubscriptionPlanModel copyWith({
    String? id,
    String? name,
    String? nameAr,
    double? price,
    double? credit,
    double? bonusPercentage,
    bool? isActive,
    int? sortOrder,
    bool clearBonusPercentage = false,
  }) {
    return SubscriptionPlanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      price: price ?? this.price,
      credit: credit ?? this.credit,
      bonusPercentage: clearBonusPercentage
          ? null
          : (bonusPercentage ?? this.bonusPercentage),
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
