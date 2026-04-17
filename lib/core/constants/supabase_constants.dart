// Table names — PostgREST / Supabase public schema.
const String kTableCustomers = 'customers';
const String kTableStaff = 'staff';
const String kTableTransactions = 'transactions';
const String kTableSubscriptionPlans = 'subscription_plans';
const String kTablePromotions = 'promotions';
const String kTableNotificationsLog = 'notifications_log';
const String kTableFraudFlags = 'fraud_flags';
const String kTableAuditLog = 'audit_log';

// —— customers columns ——
const String kCustomersId = 'id';
const String kCustomersAuthUserId = 'auth_user_id';
const String kCustomersPhone = 'phone';
const String kCustomersName = 'name';
const String kCustomersAvatarUrl = 'avatar_url';
const String kCustomersCashbackBalance = 'cashback_balance';
const String kCustomersSubscriptionBalance = 'subscription_balance';
const String kCustomersTier = 'tier';
const String kCustomersActiveSubscriptionPlanId =
    'active_subscription_plan_id';
const String kCustomersActivePlanName = 'active_plan_name';
const String kCustomersActivePlanNameAr = 'active_plan_name_ar';
const String kCustomersTotalSpent = 'total_spent';
const String kCustomersVisitCount = 'visit_count';
const String kCustomersStreakCount = 'streak_count';
const String kCustomersLastVisitDate = 'last_visit_date';
const String kCustomersBirthday = 'birthday';
const String kCustomersReferralCode = 'referral_code';
const String kCustomersReferredBy = 'referred_by';
const String kCustomersDeviceToken = 'device_token';
const String kCustomersPreferredLanguage = 'preferred_language';
const String kCustomersIsBlocked = 'is_blocked';
const String kCustomersStoreId = 'store_id';
const String kCustomersCreatedAt = 'created_at';
const String kCustomersUpdatedAt = 'updated_at';

// —— staff columns ——
const String kStaffId = 'id';
const String kStaffAuthUserId = 'auth_user_id';
const String kStaffPhone = 'phone';
const String kStaffName = 'name';
const String kStaffPinHash = 'pin_hash';
const String kStaffRole = 'role';
const String kStaffBranch = 'branch';
const String kStaffIsActive = 'is_active';
const String kStaffStoreId = 'store_id';
const String kStaffLastLogin = 'last_login';
const String kStaffCreatedAt = 'created_at';

// —— transactions columns ——
const String kTransactionsId = 'id';
const String kTransactionsIdempotencyKey = 'idempotency_key';
const String kTransactionsCustomerId = 'customer_id';
const String kTransactionsUserId = 'user_id';
const String kTransactionsStaffId = 'staff_id';
const String kTransactionsType = 'type';
const String kTransactionsAmount = 'amount';
const String kTransactionsCashbackEarned = 'cashback_earned';
const String kTransactionsStoreId = 'store_id';
const String kTransactionsSubscriptionUsed = 'subscription_used';
const String kTransactionsCashbackUsed = 'cashback_used';
const String kTransactionsBalanceBeforeCashback = 'balance_before_cashback';
const String kTransactionsBalanceBeforeSubscription =
    'balance_before_subscription';
const String kTransactionsBalanceAfterCashback = 'balance_after_cashback';
const String kTransactionsBalanceAfterSubscription =
    'balance_after_subscription';
const String kTransactionsNotes = 'notes';
const String kTransactionsDeviceId = 'device_id';
const String kTransactionsIsUndone = 'is_undone';
const String kTransactionsUndoneAt = 'undone_at';
const String kTransactionsUndoneBy = 'undone_by';
const String kTransactionsCreatedAt = 'created_at';

// —— subscription_plans columns ——
const String kSubscriptionPlansId = 'id';
const String kSubscriptionPlansName = 'name';
const String kSubscriptionPlansNameAr = 'name_ar';
const String kSubscriptionPlansPrice = 'price';
const String kSubscriptionPlansCredit = 'credit';
const String kSubscriptionPlansBonusPercentage = 'bonus_percentage';
const String kSubscriptionPlansIsActive = 'is_active';
const String kSubscriptionPlansSortOrder = 'sort_order';
const String kSubscriptionPlansStoreId = 'store_id';

// —— promotions columns (reference) ——
const String kPromotionsId = 'id';
const String kPromotionsTitle = 'title';
const String kPromotionsTitleAr = 'title_ar';
const String kPromotionsType = 'type';
const String kPromotionsCashbackOverride = 'cashback_override';
const String kPromotionsBonusAmount = 'bonus_amount';
const String kPromotionsConditions = 'conditions';
const String kPromotionsStartsAt = 'starts_at';
const String kPromotionsEndsAt = 'ends_at';
const String kPromotionsIsActive = 'is_active';
const String kPromotionsCreatedAt = 'created_at';

// —— notifications_log columns (reference) ——
const String kNotificationsLogId = 'id';
const String kNotificationsLogCustomerId = 'customer_id';
const String kNotificationsLogType = 'type';
const String kNotificationsLogChannel = 'channel';
const String kNotificationsLogMessage = 'message';
const String kNotificationsLogSentAt = 'sent_at';
const String kNotificationsLogDelivered = 'delivered';
const String kNotificationsLogTransactionId = 'transaction_id';

// —— fraud_flags columns (reference) ——
const String kFraudFlagsId = 'id';
const String kFraudFlagsTransactionId = 'transaction_id';
const String kFraudFlagsStaffId = 'staff_id';
const String kFraudFlagsCustomerId = 'customer_id';
const String kFraudFlagsFlagType = 'flag_type';
const String kFraudFlagsAutoDetected = 'auto_detected';
const String kFraudFlagsReviewedBy = 'reviewed_by';
const String kFraudFlagsResolved = 'resolved';
const String kFraudFlagsNotes = 'notes';
const String kFraudFlagsStoreId = 'store_id';
const String kFraudFlagsCreatedAt = 'created_at';

// —— audit_log columns (reference) ——
const String kAuditLogId = 'id';
const String kAuditLogActorId = 'actor_id';
const String kAuditLogActorType = 'actor_type';
const String kAuditLogAction = 'action';
const String kAuditLogTableName = 'table_name';
const String kAuditLogRecordId = 'record_id';
const String kAuditLogOldValues = 'old_values';
const String kAuditLogNewValues = 'new_values';
const String kAuditLogIpAddress = 'ip_address';
const String kAuditLogDeviceId = 'device_id';
const String kAuditLogCreatedAt = 'created_at';

// —— Storage buckets ——
const String kBucketProfilePhotos = 'profile_photos';

// —— Edge Functions (slug = URL path after /functions/v1/) ——
const String kFnAddPurchase = 'add-purchase';
const String kFnRedeemBalance = 'redeem-balance';
const String kFnAddSubscription = 'add-subscription';
const String kFnGetCustomerByQr = 'get-customer-by-qr';
const String kFnGenerateQrToken = 'generate-qr-token';
const String kFnGetOwnerDashboard = 'get-owner-dashboard';
const String kFnSendNotification = 'send-notification';
const String kFnScheduledNotifications = 'scheduled-notifications';
const String kFnUndoTransaction = 'undo-transaction';
const String kFnOwnerAdjustBalance = 'owner-customer-adjust-balance';
const String kFnOwnerSetBlocked = 'owner-customer-set-blocked';
const String kFnOwnerStaffActive = 'owner-staff-set-active';
const String kFnOwnerFraudResolve = 'owner-fraud-resolve';
const String kFnOwnerInviteStaff = 'owner-invite-staff';
const String kFnGenerateGoogleWalletUrl = 'generate-google-wallet-url';
const String kFnGeneratePasskitWalletUrl = 'generate-passkit-wallet-url';
