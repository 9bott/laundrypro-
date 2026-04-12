// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appName => 'Point';

  @override
  String get tagline => 'গণনা করুন, উপার্জন করুন, সঞ্চয় করুন';

  @override
  String get enterPhone => 'আপনার ফোন নম্বর লিখুন';

  @override
  String get sendOtp => 'যাচাইকরণ কোড পাঠান';

  @override
  String get loginAsStaff => 'স্টাফ হিসেবে লগ ইন';

  @override
  String otpSentTo(String phone) {
    return '$phone নম্বরে পাঠানো কোড লিখুন';
  }

  @override
  String get resendOtp => 'কোড পাননি? আবার পাঠান';

  @override
  String resendIn(int seconds) {
    return '$seconds সেকেন্ডে আবার পাঠান';
  }

  @override
  String welcomeUser(String name) {
    return 'স্বাগতম, $name';
  }

  @override
  String get subscriptionBalance => 'সাবস্ক্রিপশন ব্যালেন্স';

  @override
  String get cashbackBalance => 'ক্যাশব্যাক';

  @override
  String get showQrToStaff => 'এই QR দেখান বা স্টাফকে আপনার ফোন নম্বর বলুন';

  @override
  String qrRefreshIn(int seconds) {
    return 'রিফ্রেশ: $seconds সেকেন্ডে';
  }

  @override
  String get staticLoyaltyQrHint => 'Google/Apple Wallet কার্ডের একই কোড';

  @override
  String get customerQrExpired => 'কোডের মেয়াদ শেষ — রিফ্রেশ করতে ট্যাপ করুন';

  @override
  String get qrTokenServerConfigError =>
      'QR তৈরি করা যায়নি: সার্ভার কনফিগার করা নেই। Edge Function secrets-এ SUPABASE_JWT_SECRET অথবা QR_JWT_SECRET বা SUPABASE1_JWT_SECRET সেট করুন এবং generate-qr-token ডিপ্লয় করুন।';

  @override
  String get qrTokenAuthError =>
      'অ্যাকাউন্ট যাচাই করা যায়নি। রিফ্রেশ করুন বার সাইন আউট করে আবার সাইন ইন করুন।';

  @override
  String get orTellPhone => 'অথবা স্টাফকে আপনার ফোন নম্বর বলুন:';

  @override
  String get myBalance => 'আমার ব্যালেন্স';

  @override
  String get walletTitle => 'Wallet';

  @override
  String get walletSubtitle => 'Add your loyalty card to your phone wallet.';

  @override
  String get addToGoogleWallet => 'Add to Google Wallet';

  @override
  String get addToAppleWallet => 'Add to Apple Wallet';

  @override
  String get appleWalletTitle => 'Apple Wallet';

  @override
  String get appleWalletNotEnabled =>
      'Apple Wallet is not enabled yet. It requires Apple Pass Type certificate setup.';

  @override
  String get walletAddFailed =>
      'Couldn\'t generate wallet pass. Please try again.';

  @override
  String get walletOpenFailed => 'Couldn\'t open wallet. Please try again.';

  @override
  String get usedFirst => 'পেমেন্টে আগে ব্যবহৃত হয়';

  @override
  String get cashbackRate => 'প্রতিটি কেনাকাটায় ২০% ক্যাশব্যাক';

  @override
  String totalBalance(String amount) {
    return 'মোট: $amount SAR';
  }

  @override
  String get transactionHistory => 'লেনদেনের ইতিহাস';

  @override
  String get recentTransactionsTitle => 'সাম্প্রতিক লেনদেন';

  @override
  String get recentSubscriptionsTitle => 'সাম্প্রতিক সাবস্ক্রিপশন';

  @override
  String get filterAll => 'সব';

  @override
  String get filterPurchase => 'ক্রয়';

  @override
  String get filterRedemption => 'রিডেম্পশন';

  @override
  String get filterSubscription => 'সাবস্ক্রিপশন';

  @override
  String get filterBonus => 'পুরস্কার';

  @override
  String get noTransactions => 'এখনও কোনো লেনদেন নেই';

  @override
  String get nothingToShow => 'দেখানোর মতো কিছু নেই';

  @override
  String get subscriptionScreenSubtitle =>
      'আপনার জন্য উপযুক্ত সাবস্ক্রিপশন প্ল্যান বেছে নিন';

  @override
  String get balanceSubscriptionHelp => 'পেমেন্টে আগে ব্যবহৃত হয়';

  @override
  String get balanceCashbackHelp => 'প্রতিটি কেনাকাটা থেকে ২০%';

  @override
  String get topUpBalance => 'ব্যালেন্স টপ আপ';

  @override
  String get rechargeTagline => 'কম খরচে, বেশি ক্রেডিট';

  @override
  String pay(String amount) {
    return '$amount SAR পরিশোধ করুন';
  }

  @override
  String get(String amount) {
    return '$amount SAR ক্রেডিট পান';
  }

  @override
  String get mostPopular => 'সবচেয়ে জনপ্রিয়';

  @override
  String get howToBuy => 'কীভাবে কিনবেন?';

  @override
  String get howToBuyStep1 => 'স্টাফকে আপনার পছন্দের প্ল্যান বলুন';

  @override
  String get howToBuyStep2 => 'স্টাফকে নগদ পরিশোধ করুন';

  @override
  String get howToBuyStep3 =>
      'স্টাফ তৎক্ষণাৎ আপনার অ্যাকাউন্টে ক্রেডিট যোগ করবে';

  @override
  String get profile => 'প্রোফাইল';

  @override
  String get referralCode => 'আপনার রেফারেল কোড';

  @override
  String referralShare(String code) {
    return 'Point-এ আমার সঙ্গে যোগ দিন এবং ৫ SAR পান! আমার কোড: $code';
  }

  @override
  String referredCount(int count) {
    return 'রেফারেল: $count জন';
  }

  @override
  String get logout => 'লগ আউট';

  @override
  String get enterPin => 'PIN লিখুন';

  @override
  String get wrongPin => 'ভুল PIN';

  @override
  String lockedOut(int minutes) {
    return 'লক হয়েছে। $minutes মিনিট পর আবার চেষ্টা করুন';
  }

  @override
  String get scanQr => 'গ্রাহকের QR কোডে ক্যামেরা নির্দেশ করুন';

  @override
  String get enterPhone2 => 'ফোন নম্বর লিখুন';

  @override
  String get qrExpired => 'QR মেয়াদ শেষ — গ্রাহককে রিফ্রেশ করতে বলুন';

  @override
  String get invalidQr => 'অবৈধ QR';

  @override
  String get recordPurchase => 'ক্রয় রেকর্ড করুন';

  @override
  String get redeemBalance => 'ব্যালেন্স রিডিম করুন';

  @override
  String get addSubscription => 'সাবস্ক্রিপশন যোগ করুন';

  @override
  String get addsCashback => '২০% ক্যাশব্যাক যোগ করে';

  @override
  String get deductsFromBalance => 'গ্রাহকের ব্যালেন্স থেকে কাটে';

  @override
  String get topUpWithCash => 'নগদে ব্যালেন্স টপ আপ';

  @override
  String visitNumber(int count) {
    return 'ভিজিট #$count';
  }

  @override
  String get cashPaid => 'নগদ পরিশোধ';

  @override
  String get cashbackAdded => 'ক্যাশব্যাক যোগ হয়েছে';

  @override
  String get balanceAfter => 'লেনদেনের পর ব্যালেন্স';

  @override
  String get amountRedeemed => 'রিডিম করা পরিমাণ';

  @override
  String get fromSubscription => 'সাবস্ক্রিপশন ব্যালেন্স থেকে';

  @override
  String get fromCashback => 'ক্যাশব্যাক থেকে';

  @override
  String get remainingBalance => 'অবশিষ্ট ব্যালেন্স';

  @override
  String get confirmOperation => 'লেনদেন নিশ্চিত করুন';

  @override
  String get cancel => 'বাতিল';

  @override
  String get operationSuccess => 'সফল!';

  @override
  String get smsSent => 'গ্রাহককে SMS পাঠানো হয়েছে';

  @override
  String returningIn(int seconds) {
    return 'ক্যামেরায় ফিরছে: $seconds সেকেন্ডে';
  }

  @override
  String get undoOperation => 'লেনদেন পূর্বাবস্থায় ফেরান';

  @override
  String undoAvailable(int seconds) {
    return 'উপলব্ধ: $seconds সেকেন্ড';
  }

  @override
  String cashbackPreview(String amount) {
    return 'গ্রাহক পাবেন: $amount SAR ক্যাশব্যাক';
  }

  @override
  String get insufficientBalance => 'অপর্যাপ্ত ব্যালেন্স';

  @override
  String available(String amount) {
    return 'উপলব্ধ: $amount SAR';
  }

  @override
  String get confirmCashReceived =>
      'সাবস্ক্রিপশন যোগ করার আগে নগদ পেয়েছেন নিশ্চিত করুন';

  @override
  String get offlineBanner => 'আপনি অফলাইনে আছেন';

  @override
  String pendingTransactions(int count) {
    return '$count লেনদেন অপেক্ষমাণ';
  }

  @override
  String get dashboard => 'ড্যাশবোর্ড';

  @override
  String get today => 'আজ';

  @override
  String get thisWeek => 'এই সপ্তাহ';

  @override
  String get thisMonth => 'এই মাস';

  @override
  String get custom => 'কাস্টম';

  @override
  String get revenue => 'রাজস্ব';

  @override
  String get transactions => 'লেনদেন';

  @override
  String get newCustomers => 'নতুন গ্রাহক';

  @override
  String get cashbackIssued => 'ইস্যুকৃত ক্যাশব্যাক';

  @override
  String get subscriptionsSold => 'বিক্রি সাবস্ক্রিপশন';

  @override
  String get fraudAlerts => 'জালিয়াতি সতর্কতা';

  @override
  String get topCustomers => 'শীর্ষ গ্রাহক';

  @override
  String get staffActivity => 'স্টাফ কার্যকলাপ';

  @override
  String get exportCsv => 'CSV এক্সপোর্ট';

  @override
  String get adjustBalance => 'ব্যালেন্স সমন্বয়';

  @override
  String get blockCustomer => 'গ্রাহক ব্লক করুন';

  @override
  String get unblockCustomer => 'ব্লক খুলুন';

  @override
  String get inviteStaff => 'নতুন স্টাফ আমন্ত্রণ';

  @override
  String get deactivateStaff => 'অ্যাকাউন্ট নিষ্ক্রিয় করুন';

  @override
  String get markReviewed => 'পর্যালোচিত চিহ্নিত করুন';

  @override
  String get reverseTransaction => 'লেনদেন বিপরীত করুন';

  @override
  String get bronze => 'ব্রোঞ্জ';

  @override
  String get silver => 'রূপা';

  @override
  String get gold => 'সোনা';

  @override
  String get sarSuffix => ' SAR';

  @override
  String get language => 'ভাষা';

  @override
  String get arabic => 'আরবি';

  @override
  String get english => 'ইংরেজি';

  @override
  String get bengali => 'বাংলা';

  @override
  String get enterName => 'আপনার নাম লিখুন';

  @override
  String get name => 'নাম';

  @override
  String get idLabel => 'আইডি';

  @override
  String get birthday => 'জন্মদিন';

  @override
  String get notifications => 'বিজ্ঞপ্তি';

  @override
  String get enableNotifications => 'বিজ্ঞপ্তি চালু করুন';

  @override
  String get next => 'পরবর্তী';

  @override
  String get confirm => 'নিশ্চিত করুন';

  @override
  String get search => 'খুঁজুন';

  @override
  String get loading => 'লোড হচ্ছে…';

  @override
  String get error => 'কিছু ভুল হয়েছে';

  @override
  String get retry => 'আবার চেষ্টা';

  @override
  String get save => 'সংরক্ষণ';

  @override
  String get close => 'বন্ধ';

  @override
  String get yes => 'হ্যাঁ';

  @override
  String get no => 'না';

  @override
  String get dailyLimitExceeded => 'দৈনিক লেনদেন সীমা অতিক্রম';

  @override
  String get customerCardTitle => 'গ্রাহক কার্ড';

  @override
  String get customerInformation => 'গ্রাহকের তথ্য';

  @override
  String get totalSpentLabel => 'মোট খরচ';

  @override
  String get streakLabel => 'স্ট্রিক';

  @override
  String get registeredOn => 'নিবন্ধনের তারিখ';

  @override
  String get blockedBadge => 'ব্লক করা';

  @override
  String get customerNotFound => 'গ্রাহক পাওয়া যায়নি';

  @override
  String get operationFailed => 'অপারেশন ব্যর্থ — আবার চেষ্টা করুন';

  @override
  String get sessionExpired => 'সেশন শেষ — আবার সাইন ইন করুন';

  @override
  String get statTotalCustomers => 'মোট গ্রাহক';

  @override
  String get statStaffMembers => 'স্টাফ';

  @override
  String get statTodayTransactionsCount => 'আজকের লেনদেন';

  @override
  String get statTodaySalesLabel => 'আজকের বিক্রি';

  @override
  String get statTodayCashbackLabel => 'আজকের ক্যাশব্যাক';

  @override
  String get currencyDisplay => 'SAR';

  @override
  String get customersTitle => 'গ্রাহক';

  @override
  String get navHome => 'হোম';

  @override
  String get navPlans => 'প্ল্যান';

  @override
  String get tabScanner => 'স্ক্যানার';

  @override
  String get tabStore => 'স্টোর';

  @override
  String get roleManager => 'ম্যানেজার';

  @override
  String get roleStaffMember => 'স্টাফ';

  @override
  String get roleOwnerLabel => 'মালিক';

  @override
  String get mainBranch => 'প্রধান শাখা';

  @override
  String get mobilePhone => 'মোবাইল নম্বর';

  @override
  String get branchLabel => 'শাখা';

  @override
  String get roleField => 'ভূমিকা';

  @override
  String get statusField => 'অবস্থা';

  @override
  String get statusActive => 'সক্রিয়';

  @override
  String get statusInactive => 'নিষ্ক্রিয়';

  @override
  String get staffCreatedOtpSent =>
      'স্টাফ তৈরি হয়েছে — ফোনে OTP পাঠানো হয়েছে';

  @override
  String get pendingOfflineTooltip => 'অফলাইনে মুলতুবি';

  @override
  String get phoneLabelShort => 'ফোন';

  @override
  String get share => 'শেয়ার';

  @override
  String get loadMore => 'আরও লোড';

  @override
  String get visits => 'ভিজিট';

  @override
  String get lastVisit => 'শেষ ভিজিট';

  @override
  String get accountSettingsSubtitle => 'অ্যাকাউন্ট ও সেটিংস';

  @override
  String get sectionInformation => 'তথ্য';

  @override
  String get sectionPreferences => 'পছন্দসমূহ';

  @override
  String get tapToEditName => 'নাম সম্পাদনা করতে ট্যাপ করুন';

  @override
  String get contactUsTitle => 'যোগাযোগ করুন';

  @override
  String get contactUsSubtitle => 'শাখার তথ্য ও ফোন নম্বর';

  @override
  String get branchesEmpty => 'কোনো শাখা নেই';

  @override
  String get addressLabel => 'ঠিকানা';

  @override
  String get whatsappLabel => 'হোয়াটসঅ্যাপ';

  @override
  String get callAction => 'কল করুন';

  @override
  String get whatsappAction => 'হোয়াটসঅ্যাপ';

  @override
  String get teamSectionTitle => 'আমাদের দল';

  @override
  String get nameRequired => 'অনুগ্রহ করে নাম লিখুন';

  @override
  String youEarned(String amount) {
    return 'আপনি উপার্জন করেছেন $amount';
  }

  @override
  String get registerYourName => 'আপনার নাম';

  @override
  String get registerFullNameHint => 'পূর্ণ নাম';

  @override
  String get welcomeDialogTitle => 'স্বাগতম! 🌟';

  @override
  String get welcomeDialogBody =>
      'Point-এ যোগ দিয়ে আনন্দিত।\nপ্রতিটি পয়েন্ট = আরও সঞ্চয় 💙';

  @override
  String get welcomeGiftBadge => 'স্বাগতম উপহার';

  @override
  String get welcomeGiftAmount => '10.00 SAR';

  @override
  String get welcomeGiftCaption => 'আপনার অ্যাকাউন্টে বিনামূল্যে ক্যাশব্যাক';

  @override
  String get welcomeGetStarted => 'শুরু করুন 🚀';

  @override
  String get homeBalanceReady => 'আপনার ব্যালেন্স প্রস্তুত';

  @override
  String get homeLoadErrorMessage => 'কিছু ভুল হয়েছে, আবার চেষ্টা করুন';

  @override
  String get loadingTakingLong => 'লোড হতে স্বাভাবিকের চেয়ে বেশি সময় লাগছে';

  @override
  String errorWithMessage(String message) {
    return 'ত্রুটি: $message';
  }

  @override
  String get unknownError => 'অজানা';

  @override
  String get subscriptionShort => 'সাবস্ক্রিপশন';

  @override
  String get planLabelPremium => 'প্রিমিয়াম';

  @override
  String get planLabelDiamond => 'ডায়মন্ড';

  @override
  String get planPayHeader => 'পরিশোধ';

  @override
  String get planGetHeader => 'পান';

  @override
  String savePercentLabel(String percent) {
    return '$percent সাশ্রয়';
  }

  @override
  String get txTypeCashbackEarnedShort => 'ক্যাশব্যাক';

  @override
  String get txTypeAdjustment => 'সমন্বয়';

  @override
  String get signInWithBiometrics => 'বায়োমেট্রিক / Face ID দিয়ে সাইন ইন';

  @override
  String get biometricLoginTitle => 'বায়োমেট্রিক সাইন-ইন';

  @override
  String get statusOn => 'চালু';

  @override
  String get statusOff => 'বন্ধ';

  @override
  String get searchHint => 'খুঁজুন…';

  @override
  String get fraudFlagSelfTx => 'স্টাফ নিজের ফোনে ক্রেডিট দিয়েছে';

  @override
  String get fraudFlagVelocity => 'দ্রুত পুনরাবৃত্ত লেনদেন';

  @override
  String get fraudFlagLarge => 'বড় অঙ্ক পর্যালোচনা দরকার';

  @override
  String get fraudFlagDevice => 'সন্দেহজনক ডিভাইস';

  @override
  String get filterDormant => 'নিষ্ক্রিয় (৩০ দিন)';

  @override
  String get reasonRequired => 'কারণ (প্রয়োজন)';

  @override
  String get staffListTitle => 'স্টাফ';

  @override
  String get currentSubscriptionBalancePrefix =>
      'বর্তমান সাবস্ক্রিপশন ব্যালেন্স:';

  @override
  String get totalColon => 'মোট:';

  @override
  String get balanceHowItWorks => 'কীভাবে কাজ করে';

  @override
  String get balanceStepPayCash => 'নগদে পরিশোধ করুন';

  @override
  String get balanceStepCashback => '২০% ক্যাশব্যাক পান';

  @override
  String get balanceStepUseNext => 'পরবর্তী ভিজিটে ব্যবহার করুন';

  @override
  String staffSummaryRedeemBalanceAfter(String amount) {
    return 'লেনদেনের পর ব্যালেন্স: $amount';
  }

  @override
  String get actionDeactivate => 'নিষ্ক্রিয় করুন';

  @override
  String get actionActivate => 'সক্রিয় করুন';

  @override
  String get cashbackEarnedSuffix => 'ক্যাশব্যাক';

  @override
  String get staffSearchByPhone => 'ফোন নম্বর দিয়ে খুঁজুন';

  @override
  String get staffScanCustomerQr => 'গ্রাহকের QR কোড স্ক্যান করুন';

  @override
  String get staffFindCustomer => 'একজন গ্রাহক খুঁজুন';

  @override
  String get staffEnterNineDigits => '৯ সংখ্যা লিখুন';

  @override
  String get staffNoCustomerForPhone => 'এই নম্বরে কোনো গ্রাহক নেই';

  @override
  String get staffPickCustomer => 'গ্রাহক বেছে নিন:';

  @override
  String get staffOfflineTxSaved =>
      'কানেকশন নেই — লেনদেন সংরক্ষিত হয়েছে এবং স্বয়ংক্রিয়ভাবে পাঠানো হবে';

  @override
  String staffAmountSar(String amount) {
    return '$amount SAR';
  }

  @override
  String get staffSaudiRiyal => 'সৌদি রিয়াল';

  @override
  String staffAvailableSar(String amount) {
    return 'উপলব্ধ: $amount SAR';
  }

  @override
  String staffCashbackPreviewPlus(String amount) {
    return '✨ ক্যাশব্যাক: +$amount SAR';
  }

  @override
  String staffSummaryPurchAmountPaid(String amount) {
    return 'পরিশোধিত অঙ্ক: $amount';
  }

  @override
  String staffSummaryPurchCbAdded(String amount) {
    return 'ক্যাশব্যাক যোগ হয়েছে: +$amount';
  }

  @override
  String staffSummaryPurchCbAfter(String amount) {
    return 'লেনদেনের পর ক্যাশব্যাক ব্যালেন্স: $amount';
  }

  @override
  String staffSummaryRedeemAmount(String amount) {
    return 'রিডিম করা অঙ্ক: $amount';
  }

  @override
  String staffSummaryRedeemFromSub(String amount) {
    return 'সাবস্ক্রিপশন ব্যালেন্স থেকে: $amount';
  }

  @override
  String staffSummaryRedeemFromCb(String amount) {
    return 'ক্যাশব্যাক থেকে: $amount';
  }

  @override
  String staffSubscriptionBalanceLine(String amount) {
    return 'বর্তমান সাবস্ক্রিপশন ব্যালেন্স: $amount';
  }

  @override
  String staffPlanCustomerPaysCash(String amount) {
    return 'গ্রাহক পরিশোধ করবে: $amount নগদ';
  }

  @override
  String staffPlanCustomerGetsCredit(String amount) {
    return 'পাবে: $amount ক্রেডিট';
  }

  @override
  String get staffConfirmAddSubscription => 'সাবস্ক্রিপশন যোগ নিশ্চিত করুন';

  @override
  String get staffTransactionCompleted => 'লেনদেন সফলভাবে সম্পন্ন হয়েছে!';

  @override
  String get staffUndoDialogTitle => 'এই লেনদেন পূর্বাবস্থায় ফেরাবেন?';

  @override
  String get staffUndoDialogBody => 'গ্রাহকের লেনদেন বাতিল করা হবে।';

  @override
  String get staffConfirmUndo => 'পূর্বাবস্থা নিশ্চিত করুন';

  @override
  String get staffTransactionUndone => 'লেনদেন পূর্বাবস্থায় ফেরানো হয়েছে';

  @override
  String get staffUndoShort => 'পূর্বাবস্থা';

  @override
  String get staffSuccCustomer => 'গ্রাহক';

  @override
  String get staffSuccAmountPaid => 'পরিশোধিত অঙ্ক';

  @override
  String get staffSuccCashbackAdded => 'ক্যাশব্যাক যোগ হয়েছে';

  @override
  String get staffSuccCashbackNow => 'এখন ক্যাশব্যাক ব্যালেন্স';

  @override
  String get staffSuccAmountRedeemed => 'রিডিম করা অঙ্ক';

  @override
  String get staffSuccFromSubscription => 'সাবস্ক্রিপশন থেকে';

  @override
  String get staffSuccFromCashback => 'ক্যাশব্যাক থেকে';

  @override
  String get staffSuccSubAfter => 'সাবস্ক্রিপশন ব্যালেন্স পরে';

  @override
  String get staffSuccCashbackAfter => 'ক্যাশব্যাক পরে';

  @override
  String get staffSuccPaidCash => 'নগদে পরিশোধ';

  @override
  String get staffSuccCreditAdded => 'ক্রেডিট যোগ হয়েছে';

  @override
  String get staffSuccSubNow => 'এখন সাবস্ক্রিপশন ব্যালেন্স';
}
