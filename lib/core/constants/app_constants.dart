/// Global business rules and tuning constants.

/// SharedPreferences: phone auth — [`kLoginModeStaff`] checks staff before customer after OTP.
const String kLoginModePrefKey = 'login_mode';
const String kLoginModeStaff = 'staff';
const String kLoginModeCustomer = 'customer';

/// SharedPreferences: auth convenience
const String kRememberMePrefKey = 'remember_me';

const double kCashbackRate = 0.20;

/// Pay 100 SAR → 120 SAR prepaid credit (example tier).
const double kSubscriptionBonus100 = 120.0;

/// Pay 200 SAR → 250 SAR prepaid credit (example tier).
const double kSubscriptionBonus200 = 250.0;

/// Pay 500 SAR → 650 SAR prepaid credit (example tier).
const double kSubscriptionBonus500 = 650.0;

/// كان يُستخدم لفترة تجديد QR — التجديد التلقائي معطّل حالياً.
const int kQrRefreshSeconds = 60;

/// Staff undo window after recording a transaction.
const int kUndoWindowSeconds = 30;

/// Max recorded transactions per customer per day (fraud / policy).
const int kDailyTransactionLimit = 3;

/// Flag unusually large single cash payments.
const double kFraudAlertAmount = 200.0;
