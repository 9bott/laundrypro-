import '../../core/constants/supabase_constants.dart';
import 'model_parsing.dart';

class CustomerModel {
  const CustomerModel({
    required this.id,
    this.authUserId,
    required this.phone,
    required this.name,
    this.avatarUrl,
    required this.cashbackBalance,
    required this.subscriptionBalance,
    required this.tier,
    this.activeSubscriptionPlanId,
    this.activePlanName,
    this.activePlanNameAr,
    required this.totalSpent,
    required this.visitCount,
    required this.streakCount,
    this.lastVisitDate,
    this.birthday,
    this.referralCode,
    this.referredBy,
    this.deviceToken,
    required this.preferredLanguage,
    required this.isBlocked,
    required this.storeId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? authUserId;
  final String phone;
  final String name;
  final String? avatarUrl;
  final double cashbackBalance;
  final double subscriptionBalance;
  final String tier;
  final String? activeSubscriptionPlanId;
  final String? activePlanName;
  final String? activePlanNameAr;
  final double totalSpent;
  final int visitCount;
  final int streakCount;
  final DateTime? lastVisitDate;
  final DateTime? birthday;
  final String? referralCode;
  final String? referredBy;
  final String? deviceToken;
  final String preferredLanguage;
  final bool isBlocked;
  final String storeId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json[kCustomersId]! as String,
      authUserId: modelParseString(json[kCustomersAuthUserId]),
      phone: json[kCustomersPhone]! as String,
      name: json[kCustomersName]! as String,
      avatarUrl: modelParseString(json[kCustomersAvatarUrl]),
      cashbackBalance: modelParseDouble(json[kCustomersCashbackBalance]),
      subscriptionBalance: modelParseDouble(json[kCustomersSubscriptionBalance]),
      tier: json[kCustomersTier] as String? ?? 'bronze',
      activeSubscriptionPlanId:
          modelParseString(json[kCustomersActiveSubscriptionPlanId]),
      activePlanName: modelParseString(json[kCustomersActivePlanName]),
      activePlanNameAr: modelParseString(json[kCustomersActivePlanNameAr]),
      totalSpent: modelParseDouble(json[kCustomersTotalSpent]),
      visitCount: modelParseInt(json[kCustomersVisitCount]),
      streakCount: modelParseInt(json[kCustomersStreakCount]),
      lastVisitDate: modelParseDateTime(json[kCustomersLastVisitDate]),
      birthday: modelParseDateTime(json[kCustomersBirthday]),
      referralCode: modelParseString(json[kCustomersReferralCode]),
      referredBy: modelParseString(json[kCustomersReferredBy]),
      deviceToken: modelParseString(json[kCustomersDeviceToken]),
      preferredLanguage:
          json[kCustomersPreferredLanguage] as String? ?? 'ar',
      isBlocked: modelParseBool(json[kCustomersIsBlocked]),
      storeId: json[kCustomersStoreId]! as String,
      createdAt: modelParseDateTime(json[kCustomersCreatedAt])!,
      updatedAt: modelParseDateTime(json[kCustomersUpdatedAt])!,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      kCustomersId: id,
      kCustomersAuthUserId: authUserId,
      kCustomersPhone: phone,
      kCustomersName: name,
      kCustomersAvatarUrl: avatarUrl,
      kCustomersCashbackBalance: cashbackBalance,
      kCustomersSubscriptionBalance: subscriptionBalance,
      kCustomersTier: tier,
      kCustomersActiveSubscriptionPlanId: activeSubscriptionPlanId,
      kCustomersActivePlanName: activePlanName,
      kCustomersActivePlanNameAr: activePlanNameAr,
      kCustomersTotalSpent: totalSpent,
      kCustomersVisitCount: visitCount,
      kCustomersStreakCount: streakCount,
      kCustomersLastVisitDate: lastVisitDate?.toUtc().toIso8601String(),
      kCustomersBirthday: birthday != null
          ? '${birthday!.year.toString().padLeft(4, '0')}-'
              '${birthday!.month.toString().padLeft(2, '0')}-'
              '${birthday!.day.toString().padLeft(2, '0')}'
          : null,
      kCustomersReferralCode: referralCode,
      kCustomersReferredBy: referredBy,
      kCustomersDeviceToken: deviceToken,
      kCustomersPreferredLanguage: preferredLanguage,
      kCustomersIsBlocked: isBlocked,
      kCustomersStoreId: storeId,
      kCustomersCreatedAt: createdAt.toUtc().toIso8601String(),
      kCustomersUpdatedAt: updatedAt.toUtc().toIso8601String(),
    };
  }

  CustomerModel copyWith({
    String? id,
    String? authUserId,
    String? phone,
    String? name,
    String? avatarUrl,
    double? cashbackBalance,
    double? subscriptionBalance,
    String? tier,
    String? activeSubscriptionPlanId,
    String? activePlanName,
    String? activePlanNameAr,
    bool clearActiveSubscriptionPlanId = false,
    bool clearActivePlanName = false,
    bool clearActivePlanNameAr = false,
    double? totalSpent,
    int? visitCount,
    int? streakCount,
    DateTime? lastVisitDate,
    DateTime? birthday,
    String? referralCode,
    String? referredBy,
    String? deviceToken,
    String? preferredLanguage,
    bool? isBlocked,
    String? storeId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearAuthUserId = false,
    bool clearAvatarUrl = false,
    bool clearLastVisit = false,
    bool clearBirthday = false,
    bool clearReferralCode = false,
    bool clearReferredBy = false,
    bool clearDeviceToken = false,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      authUserId: clearAuthUserId ? null : (authUserId ?? this.authUserId),
      phone: phone ?? this.phone,
      name: name ?? this.name,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      cashbackBalance: cashbackBalance ?? this.cashbackBalance,
      subscriptionBalance: subscriptionBalance ?? this.subscriptionBalance,
      tier: tier ?? this.tier,
      activeSubscriptionPlanId: clearActiveSubscriptionPlanId
          ? null
          : (activeSubscriptionPlanId ?? this.activeSubscriptionPlanId),
      activePlanName:
          clearActivePlanName ? null : (activePlanName ?? this.activePlanName),
      activePlanNameAr: clearActivePlanNameAr
          ? null
          : (activePlanNameAr ?? this.activePlanNameAr),
      totalSpent: totalSpent ?? this.totalSpent,
      visitCount: visitCount ?? this.visitCount,
      streakCount: streakCount ?? this.streakCount,
      lastVisitDate:
          clearLastVisit ? null : (lastVisitDate ?? this.lastVisitDate),
      birthday: clearBirthday ? null : (birthday ?? this.birthday),
      referralCode:
          clearReferralCode ? null : (referralCode ?? this.referralCode),
      referredBy: clearReferredBy ? null : (referredBy ?? this.referredBy),
      deviceToken: clearDeviceToken ? null : (deviceToken ?? this.deviceToken),
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      isBlocked: isBlocked ?? this.isBlocked,
      storeId: storeId ?? this.storeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
