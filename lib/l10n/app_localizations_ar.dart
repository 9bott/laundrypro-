// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'Point';

  @override
  String get tagline => 'احسب، اكسب، وفّر';

  @override
  String get enterPhone => 'أدخل رقم هاتفك';

  @override
  String get sendOtp => 'إرسال رمز التحقق';

  @override
  String get loginAsStaff => 'تسجيل الدخول كموظف';

  @override
  String otpSentTo(String phone) {
    return 'أدخل الرمز المُرسل إلى $phone';
  }

  @override
  String get resendOtp => 'لم تصلك الرسالة؟ إعادة الإرسال';

  @override
  String resendIn(int seconds) {
    return 'إعادة الإرسال خلال $seconds ثانية';
  }

  @override
  String welcomeUser(String name) {
    return 'مرحباً، $name';
  }

  @override
  String get subscriptionBalance => 'رصيد الاشتراك';

  @override
  String get cashbackBalance => 'الكاش باك';

  @override
  String get showQrToStaff => 'أرِ الموظف هذا الرمز أو أعطه رقم جوالك';

  @override
  String qrRefreshIn(int seconds) {
    return 'يتجدد خلال: $seconds ثانية';
  }

  @override
  String get staticLoyaltyQrHint =>
      'نفس الرمز الموجود في بطاقة المحفظة (Google / Apple)';

  @override
  String get customerQrExpired => 'انتهت صلاحية الرمز — اضغط للتجديد';

  @override
  String get qrTokenServerConfigError =>
      'تعذر إنشاء الرمز: إعداد الخادم غير مكتمل. في أسرار الدوال اضبط SUPABASE_JWT_SECRET أو QR_JWT_SECRET أو SUPABASE1_JWT_SECRET ثم انشر generate-qr-token.';

  @override
  String get qrTokenAuthError =>
      'تعذر التحقق من حسابك. اسحب الشاشة للتحديث أو سجّل الخروج ثم الدخول مجدداً.';

  @override
  String get orTellPhone => 'أو أخبر الموظف برقم هاتفك:';

  @override
  String get myBalance => 'رصيدي';

  @override
  String get walletTitle => 'المحفظة';

  @override
  String get walletSubtitle => 'أضف بطاقة الولاء إلى محفظة هاتفك.';

  @override
  String get addToGoogleWallet => 'إضافة إلى Google Wallet';

  @override
  String get addToAppleWallet => 'إضافة إلى Apple Wallet';

  @override
  String get appleWalletTitle => 'Apple Wallet';

  @override
  String get appleWalletNotEnabled =>
      'Apple Wallet غير مفعّل حالياً. يتطلب إعداد شهادة Apple Pass Type.';

  @override
  String get walletAddFailed => 'تعذر إنشاء البطاقة. حاول مرة أخرى.';

  @override
  String get walletOpenFailed => 'تعذر فتح المحفظة. حاول مرة أخرى.';

  @override
  String get usedFirst => 'يُستخدم أولاً عند الدفع';

  @override
  String get cashbackRate => '20% من كل عملية شراء';

  @override
  String totalBalance(String amount) {
    return 'الإجمالي: $amount ريال';
  }

  @override
  String get transactionHistory => 'سجل المعاملات';

  @override
  String get recentTransactionsTitle => 'آخر العمليات';

  @override
  String get recentSubscriptionsTitle => 'آخر الاشتراكات';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterPurchase => 'شراء';

  @override
  String get filterRedemption => 'استرداد';

  @override
  String get filterSubscription => 'اشتراك';

  @override
  String get filterBonus => 'مكافآت';

  @override
  String get noTransactions => 'لا توجد معاملات بعد';

  @override
  String get nothingToShow => 'لا توجد بيانات';

  @override
  String get subscriptionScreenSubtitle => 'اختر باقة الاشتراك المناسبة لك';

  @override
  String get balanceSubscriptionHelp => 'يُستخدم أولاً عند الدفع';

  @override
  String get balanceCashbackHelp => '٢٠٪ من كل عملية شراء';

  @override
  String get topUpBalance => 'شحن الرصيد';

  @override
  String get rechargeTagline => 'ادفع أقل، واحصل على أكثر';

  @override
  String pay(String amount) {
    return 'ادفع $amount ريال';
  }

  @override
  String get(String amount) {
    return 'احصل على $amount ريال';
  }

  @override
  String get mostPopular => 'الأكثر طلباً';

  @override
  String get howToBuy => 'كيف تشتري؟';

  @override
  String get howToBuyStep1 => 'أخبر الموظف بالخطة التي تريدها';

  @override
  String get howToBuyStep2 => 'ادفع المبلغ نقداً للموظف';

  @override
  String get howToBuyStep3 => 'سيضيف الموظف الرصيد لحسابك فوراً';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get referralCode => 'رمز الإحالة الخاص بك';

  @override
  String referralShare(String code) {
    return 'انضم إلي في تطبيق Point واحصل على 5 ريال هدية! استخدم كودي: $code';
  }

  @override
  String referredCount(int count) {
    return 'المُحالون: $count شخص';
  }

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get enterPin => 'أدخل رقم PIN';

  @override
  String get wrongPin => 'PIN غير صحيح';

  @override
  String lockedOut(int minutes) {
    return 'تم القفل. حاول بعد $minutes دقيقة';
  }

  @override
  String get scanQr => 'وجّه الكاميرا نحو QR العميل';

  @override
  String get enterPhone2 => 'أدخل رقم الهاتف';

  @override
  String get qrExpired => 'QR منتهي الصلاحية، اطلب من العميل تحديثه';

  @override
  String get invalidQr => 'QR غير صحيح';

  @override
  String get recordPurchase => 'تسجيل شراء';

  @override
  String get redeemBalance => 'استرداد الرصيد';

  @override
  String get addSubscription => 'إضافة اشتراك';

  @override
  String get addsCashback => 'يضيف كاش باك 20%';

  @override
  String get deductsFromBalance => 'يخصم من رصيد العميل';

  @override
  String get topUpWithCash => 'شحن الرصيد بالكاش';

  @override
  String visitNumber(int count) {
    return 'الزيارة رقم $count';
  }

  @override
  String get cashPaid => 'المبلغ المدفوع';

  @override
  String get cashbackAdded => 'الكاش باك المضاف';

  @override
  String get balanceAfter => 'الرصيد بعد العملية';

  @override
  String get amountRedeemed => 'المبلغ المسترد';

  @override
  String get fromSubscription => 'من رصيد الاشتراك';

  @override
  String get fromCashback => 'من الكاش باك';

  @override
  String get remainingBalance => 'الرصيد المتبقي';

  @override
  String get confirmOperation => 'تأكيد العملية';

  @override
  String get cancel => 'إلغاء';

  @override
  String get operationSuccess => 'تمت العملية بنجاح!';

  @override
  String get smsSent => 'رسالة SMS تم إرسالها للعميل';

  @override
  String returningIn(int seconds) {
    return 'العودة للكاميرا خلال: $seconds';
  }

  @override
  String get undoOperation => 'تراجع عن العملية';

  @override
  String undoAvailable(int seconds) {
    return 'متاح لمدة: $seconds ثانية';
  }

  @override
  String cashbackPreview(String amount) {
    return 'سيحصل العميل على: $amount ريال كاش باك';
  }

  @override
  String get insufficientBalance => 'الرصيد غير كافٍ';

  @override
  String available(String amount) {
    return 'متاح: $amount ريال';
  }

  @override
  String get confirmCashReceived => 'تأكد من استلام النقود قبل إضافة الاشتراك';

  @override
  String get offlineBanner => 'أنت غير متصل بالإنترنت';

  @override
  String pendingTransactions(int count) {
    return '$count عملية معلقة';
  }

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get today => 'اليوم';

  @override
  String get thisWeek => 'هذا الأسبوع';

  @override
  String get thisMonth => 'هذا الشهر';

  @override
  String get custom => 'مخصص';

  @override
  String get revenue => 'الإيرادات';

  @override
  String get transactions => 'المعاملات';

  @override
  String get newCustomers => 'عملاء جدد';

  @override
  String get cashbackIssued => 'كاش باك صدر';

  @override
  String get subscriptionsSold => 'اشتراكات مباعة';

  @override
  String get fraudAlerts => 'تنبيهات احتيال';

  @override
  String get topCustomers => 'أفضل العملاء';

  @override
  String get staffActivity => 'نشاط الموظفين';

  @override
  String get exportCsv => 'تصدير CSV';

  @override
  String get adjustBalance => 'تعديل الرصيد';

  @override
  String get blockCustomer => 'حظر العميل';

  @override
  String get unblockCustomer => 'إلغاء الحظر';

  @override
  String get inviteStaff => 'دعوة موظف جديد';

  @override
  String get deactivateStaff => 'تعطيل الحساب';

  @override
  String get markReviewed => 'تم المراجعة';

  @override
  String get reverseTransaction => 'عكس العملية';

  @override
  String get bronze => 'برونزي';

  @override
  String get silver => 'فضي';

  @override
  String get gold => 'ذهبي';

  @override
  String get sarSuffix => ' ريال';

  @override
  String get language => 'اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get bengali => 'البنغالية';

  @override
  String get enterName => 'أدخل اسمك';

  @override
  String get name => 'الاسم';

  @override
  String get idLabel => 'المعرّف';

  @override
  String get birthday => 'تاريخ الميلاد';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get enableNotifications => 'تفعيل الإشعارات';

  @override
  String get next => 'التالي';

  @override
  String get confirm => 'تأكيد';

  @override
  String get search => 'بحث';

  @override
  String get loading => 'جارٍ التحميل...';

  @override
  String get error => 'حدث خطأ';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get save => 'حفظ';

  @override
  String get close => 'إغلاق';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get dailyLimitExceeded => 'تم تجاوز الحد اليومي للمعاملات';

  @override
  String get customerCardTitle => 'بطاقة العميل';

  @override
  String get customerInformation => 'معلومات العميل';

  @override
  String get totalSpentLabel => 'إجمالي المصروف';

  @override
  String get streakLabel => 'الستريك';

  @override
  String get registeredOn => 'تاريخ التسجيل';

  @override
  String get blockedBadge => 'محظور';

  @override
  String get customerNotFound => 'العميل غير موجود';

  @override
  String get operationFailed => 'فشلت العملية، حاول مجدداً';

  @override
  String get sessionExpired => 'انتهت الجلسة، سجّل الدخول مجدداً';

  @override
  String get statTotalCustomers => 'إجمالي العملاء';

  @override
  String get statStaffMembers => 'الموظفون';

  @override
  String get statTodayTransactionsCount => 'عمليات اليوم';

  @override
  String get statTodaySalesLabel => 'مبيعات اليوم';

  @override
  String get statTodayCashbackLabel => 'كاش باك اليوم';

  @override
  String get currencyDisplay => 'ريال';

  @override
  String get customersTitle => 'العملاء';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navPlans => 'الباقات';

  @override
  String get tabScanner => 'الماسح';

  @override
  String get tabStore => 'متجر';

  @override
  String get roleManager => 'مدير';

  @override
  String get roleStaffMember => 'موظف';

  @override
  String get roleOwnerLabel => 'مالك';

  @override
  String get mainBranch => 'الفرع الرئيسي';

  @override
  String get mobilePhone => 'رقم الجوال';

  @override
  String get branchLabel => 'الفرع';

  @override
  String get roleField => 'الصلاحية';

  @override
  String get statusField => 'الحالة';

  @override
  String get statusActive => 'نشط';

  @override
  String get statusInactive => 'غير نشط';

  @override
  String get staffCreatedOtpSent => 'تم إنشاء الحساب — أُرسل OTP للجوال';

  @override
  String get pendingOfflineTooltip => 'عمليات غير مرسلة';

  @override
  String get phoneLabelShort => 'الهاتف';

  @override
  String get share => 'مشاركة';

  @override
  String get loadMore => 'تحميل المزيد';

  @override
  String get visits => 'الزيارات';

  @override
  String get lastVisit => 'آخر زيارة';

  @override
  String get accountSettingsSubtitle => 'إعدادات الحساب والمعلومات';

  @override
  String get sectionInformation => 'المعلومات';

  @override
  String get sectionPreferences => 'التفضيلات';

  @override
  String get tapToEditName => 'اضغط لتعديل الاسم';

  @override
  String get contactUsTitle => 'تواصل معنا';

  @override
  String get contactUsSubtitle => 'معلومات الفروع وأرقام التواصل';

  @override
  String get branchesEmpty => 'لا توجد فروع متاحة';

  @override
  String get addressLabel => 'العنوان';

  @override
  String get whatsappLabel => 'واتساب';

  @override
  String get callAction => 'اتصل';

  @override
  String get whatsappAction => 'واتساب';

  @override
  String get teamSectionTitle => 'فريق العمل';

  @override
  String get nameRequired => 'الرجاء إدخال الاسم';

  @override
  String youEarned(String amount) {
    return 'ربحت $amount';
  }

  @override
  String get registerYourName => 'أدخل اسمك';

  @override
  String get registerFullNameHint => 'الاسم الكامل';

  @override
  String get welcomeDialogTitle => 'أهلاً وسهلاً! 🌟';

  @override
  String get welcomeDialogBody =>
      'يسعدنا انضمامك لعائلة Point\nكل نقطة = توفير أكثر 💙';

  @override
  String get welcomeGiftBadge => '🎉 هدية ترحيب';

  @override
  String get welcomeGiftAmount => '10.00 ريال';

  @override
  String get welcomeGiftCaption => 'كاش باك مجاني في حسابك';

  @override
  String get welcomeGetStarted => 'ابدأ الاستخدام 🚀';

  @override
  String get homeBalanceReady => 'رصيدك جاهز للاستخدام';

  @override
  String get homeLoadErrorMessage => 'حدث خطأ، حاول مرة أخرى';

  @override
  String get loadingTakingLong => 'يستغرق التحميل وقتاً أطول من المعتاد';

  @override
  String errorWithMessage(String message) {
    return 'خطأ: $message';
  }

  @override
  String get unknownError => 'غير معروف';

  @override
  String get subscriptionShort => 'الاشتراك';

  @override
  String get planLabelPremium => 'قيمة استثنائية';

  @override
  String get planLabelDiamond => 'ماسي';

  @override
  String get planPayHeader => 'ادفع';

  @override
  String get planGetHeader => 'احصل على';

  @override
  String savePercentLabel(String percent) {
    return 'توفير $percent';
  }

  @override
  String get txTypeCashbackEarnedShort => 'كاش باك';

  @override
  String get txTypeAdjustment => 'تعديل';

  @override
  String get signInWithBiometrics => 'الدخول بالبصمة / Face ID';

  @override
  String get biometricLoginTitle => 'تسجيل الدخول بالبصمة';

  @override
  String get statusOn => 'مفعّل';

  @override
  String get statusOff => 'غير مفعّل';

  @override
  String get searchHint => 'بحث…';

  @override
  String get fraudFlagSelfTx => 'موظف أضاف لرقمه الخاص';

  @override
  String get fraudFlagVelocity => 'معاملات متكررة بسرعة';

  @override
  String get fraudFlagLarge => 'مبلغ كبير يحتاج مراجعة';

  @override
  String get fraudFlagDevice => 'جهاز مشبوه';

  @override
  String get filterDormant => 'غير نشط ٣٠ يوم';

  @override
  String get reasonRequired => 'السبب (مطلوب)';

  @override
  String get staffListTitle => 'الموظفون';

  @override
  String get currentSubscriptionBalancePrefix => 'رصيد اشتراكك الحالي:';

  @override
  String get totalColon => 'الإجمالي:';

  @override
  String get balanceHowItWorks => 'كيف يعمل الرصيد؟';

  @override
  String get balanceStepPayCash => 'ادفع نقداً';

  @override
  String get balanceStepCashback => 'احصل على ٢٠٪ كاش باك';

  @override
  String get balanceStepUseNext => 'استخدمه في زيارتك القادمة';

  @override
  String staffSummaryRedeemBalanceAfter(String amount) {
    return 'الرصيد بعد العملية: $amount';
  }

  @override
  String get actionDeactivate => 'تعطيل';

  @override
  String get actionActivate => 'تفعيل';

  @override
  String get cashbackEarnedSuffix => 'كاش باك';

  @override
  String get staffSearchByPhone => 'البحث برقم الهاتف';

  @override
  String get staffScanCustomerQr => 'امسح رمز QR العميل';

  @override
  String get staffFindCustomer => 'ابحث عن عميل';

  @override
  String get staffEnterNineDigits => 'أدخل 9 أرقام';

  @override
  String get staffNoCustomerForPhone => 'لا يوجد عميل بهذا الرقم';

  @override
  String get staffPickCustomer => 'اختر العميل:';

  @override
  String get staffOfflineTxSaved =>
      'لا يوجد اتصال — تم حفظ العملية وستُرسل تلقائياً';

  @override
  String staffAmountSar(String amount) {
    return '$amount ريال';
  }

  @override
  String get staffSaudiRiyal => 'ريال سعودي';

  @override
  String staffAvailableSar(String amount) {
    return 'متاح: $amount ريال';
  }

  @override
  String staffCashbackPreviewPlus(String amount) {
    return '✨ الكاش باك: +$amount ريال';
  }

  @override
  String staffSummaryPurchAmountPaid(String amount) {
    return 'المبلغ المدفوع: $amount';
  }

  @override
  String staffSummaryPurchCbAdded(String amount) {
    return 'الكاش باك المضاف: +$amount';
  }

  @override
  String staffSummaryPurchCbAfter(String amount) {
    return 'رصيد الكاش باك بعد العملية: $amount';
  }

  @override
  String staffSummaryRedeemAmount(String amount) {
    return 'المبلغ المسترد: $amount';
  }

  @override
  String staffSummaryRedeemFromSub(String amount) {
    return 'من رصيد الاشتراك: $amount';
  }

  @override
  String staffSummaryRedeemFromCb(String amount) {
    return 'من الكاش باك: $amount';
  }

  @override
  String staffSubscriptionBalanceLine(String amount) {
    return 'رصيد الاشتراك الحالي: $amount';
  }

  @override
  String staffPlanCustomerPaysCash(String amount) {
    return 'العميل يدفع: $amount نقداً';
  }

  @override
  String staffPlanCustomerGetsCredit(String amount) {
    return 'يحصل على: $amount رصيد';
  }

  @override
  String get staffConfirmAddSubscription => 'تأكيد إضافة الاشتراك';

  @override
  String get staffTransactionCompleted => 'تمت العملية بنجاح!';

  @override
  String get staffUndoDialogTitle => 'تراجع عن العملية؟';

  @override
  String get staffUndoDialogBody => 'سيتم إلغاء العملية للعميل.';

  @override
  String get staffConfirmUndo => 'تأكيد التراجع';

  @override
  String get staffTransactionUndone => 'تم التراجع عن العملية';

  @override
  String get staffUndoShort => 'التراجع';

  @override
  String get staffSuccCustomer => 'العميل';

  @override
  String get staffSuccAmountPaid => 'المبلغ المدفوع';

  @override
  String get staffSuccCashbackAdded => 'الكاش باك المضاف';

  @override
  String get staffSuccCashbackNow => 'رصيد الكاش باك الآن';

  @override
  String get staffSuccAmountRedeemed => 'المبلغ المسترد';

  @override
  String get staffSuccFromSubscription => 'من الاشتراك';

  @override
  String get staffSuccFromCashback => 'من الكاش باك';

  @override
  String get staffSuccSubAfter => 'رصيد الاشتراك بعد';

  @override
  String get staffSuccCashbackAfter => 'كاش باك بعد';

  @override
  String get staffSuccPaidCash => 'تم الدفع نقداً';

  @override
  String get staffSuccCreditAdded => 'رصيد مضاف';

  @override
  String get staffSuccSubNow => 'رصيد الاشتراك الآن';
}
