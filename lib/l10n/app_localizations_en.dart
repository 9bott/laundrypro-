// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Point';

  @override
  String get tagline => 'Count, earn, save';

  @override
  String get enterPhone => 'Enter your phone number';

  @override
  String get sendOtp => 'Send verification code';

  @override
  String get loginAsStaff => 'Log in as staff';

  @override
  String otpSentTo(String phone) {
    return 'Enter the code sent to $phone';
  }

  @override
  String get resendOtp => 'Didn\'t receive it? Resend';

  @override
  String resendIn(int seconds) {
    return 'Resend in $seconds seconds';
  }

  @override
  String welcomeUser(String name) {
    return 'Welcome, $name';
  }

  @override
  String get subscriptionBalance => 'Subscription balance';

  @override
  String get cashbackBalance => 'Cashback';

  @override
  String get showQrToStaff => 'Show this QR or give your phone number to staff';

  @override
  String qrRefreshIn(int seconds) {
    return 'Refreshes in: $seconds seconds';
  }

  @override
  String get orTellPhone => 'Or tell staff your phone number:';

  @override
  String get myWallet => 'My wallet';

  @override
  String get usedFirst => 'Used first when paying';

  @override
  String get cashbackRate => '20% cashback on every purchase';

  @override
  String totalBalance(String amount) {
    return 'Total: $amount SAR';
  }

  @override
  String get transactionHistory => 'Transaction history';

  @override
  String get recentTransactionsTitle => 'Recent transactions';

  @override
  String get recentSubscriptionsTitle => 'Recent subscriptions';

  @override
  String get filterAll => 'All';

  @override
  String get filterPurchase => 'Purchase';

  @override
  String get filterRedemption => 'Redemption';

  @override
  String get filterSubscription => 'Subscription';

  @override
  String get filterBonus => 'Rewards';

  @override
  String get noTransactions => 'No transactions yet';

  @override
  String get nothingToShow => 'Nothing to show';

  @override
  String get subscriptionScreenSubtitle =>
      'Choose the subscription plan that fits you';

  @override
  String get walletSubscriptionHelp => 'Used first when paying';

  @override
  String get walletCashbackHelp => '20% from every purchase';

  @override
  String get rechargeWallet => 'Top up wallet';

  @override
  String get rechargeTagline => 'Pay less, get more credit';

  @override
  String pay(String amount) {
    return 'Pay $amount SAR';
  }

  @override
  String get(String amount) {
    return 'Get $amount SAR credit';
  }

  @override
  String get mostPopular => 'Most popular';

  @override
  String get howToBuy => 'How to buy?';

  @override
  String get howToBuyStep1 => 'Tell staff which plan you want';

  @override
  String get howToBuyStep2 => 'Pay cash to staff';

  @override
  String get howToBuyStep3 => 'Staff will add credit to your wallet instantly';

  @override
  String get profile => 'Profile';

  @override
  String get referralCode => 'Your referral code';

  @override
  String referralShare(String code) {
    return 'Join me on Point and get 5 SAR! Use my code: $code';
  }

  @override
  String referredCount(int count) {
    return 'Referrals: $count people';
  }

  @override
  String get logout => 'Log out';

  @override
  String get enterPin => 'Enter PIN';

  @override
  String get wrongPin => 'Wrong PIN';

  @override
  String lockedOut(int minutes) {
    return 'Locked. Try again in $minutes minutes';
  }

  @override
  String get scanQr => 'Point the camera at the customer QR';

  @override
  String get enterPhone2 => 'Enter phone number';

  @override
  String get qrExpired => 'QR expired — ask the customer to refresh it';

  @override
  String get invalidQr => 'Invalid QR';

  @override
  String get recordPurchase => 'Record purchase';

  @override
  String get redeemBalance => 'Redeem balance';

  @override
  String get addSubscription => 'Add subscription';

  @override
  String get addsCashback => 'Adds 20% cashback';

  @override
  String get deductsFromWallet => 'Deducts from customer wallet';

  @override
  String get rechargeWithCash => 'Top up wallet with cash';

  @override
  String visitNumber(int count) {
    return 'Visit #$count';
  }

  @override
  String get cashPaid => 'Cash paid';

  @override
  String get cashbackAdded => 'Cashback added';

  @override
  String get balanceAfter => 'Balance after transaction';

  @override
  String get amountRedeemed => 'Amount redeemed';

  @override
  String get fromSubscription => 'From subscription balance';

  @override
  String get fromCashback => 'From cashback';

  @override
  String get remainingBalance => 'Remaining balance';

  @override
  String get confirmOperation => 'Confirm transaction';

  @override
  String get cancel => 'Cancel';

  @override
  String get operationSuccess => 'Success!';

  @override
  String get smsSent => 'SMS sent to customer';

  @override
  String returningIn(int seconds) {
    return 'Returning to camera in: $seconds';
  }

  @override
  String get undoOperation => 'Undo transaction';

  @override
  String undoAvailable(int seconds) {
    return 'Available for: $seconds seconds';
  }

  @override
  String cashbackPreview(String amount) {
    return 'Customer earns: $amount SAR cashback';
  }

  @override
  String get insufficientBalance => 'Insufficient balance';

  @override
  String available(String amount) {
    return 'Available: $amount SAR';
  }

  @override
  String get confirmCashReceived =>
      'Confirm you received cash before adding subscription';

  @override
  String get offlineBanner => 'You are offline';

  @override
  String pendingTransactions(int count) {
    return '$count pending transactions';
  }

  @override
  String get dashboard => 'Dashboard';

  @override
  String get today => 'Today';

  @override
  String get thisWeek => 'This week';

  @override
  String get thisMonth => 'This month';

  @override
  String get custom => 'Custom';

  @override
  String get revenue => 'Revenue';

  @override
  String get transactions => 'Transactions';

  @override
  String get newCustomers => 'New customers';

  @override
  String get cashbackIssued => 'Cashback issued';

  @override
  String get subscriptionsSold => 'Subscriptions sold';

  @override
  String get fraudAlerts => 'Fraud alerts';

  @override
  String get topCustomers => 'Top customers';

  @override
  String get staffActivity => 'Staff activity';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String get adjustBalance => 'Adjust balance';

  @override
  String get blockCustomer => 'Block customer';

  @override
  String get unblockCustomer => 'Unblock customer';

  @override
  String get inviteStaff => 'Invite new staff';

  @override
  String get deactivateStaff => 'Deactivate account';

  @override
  String get markReviewed => 'Mark reviewed';

  @override
  String get reverseTransaction => 'Reverse transaction';

  @override
  String get bronze => 'Bronze';

  @override
  String get silver => 'Silver';

  @override
  String get gold => 'Gold';

  @override
  String get sarSuffix => ' SAR';

  @override
  String get language => 'Language';

  @override
  String get arabic => 'Arabic';

  @override
  String get english => 'English';

  @override
  String get bengali => 'Bengali';

  @override
  String get enterName => 'Enter your name';

  @override
  String get name => 'Name';

  @override
  String get idLabel => 'ID';

  @override
  String get birthday => 'Birthday';

  @override
  String get notifications => 'Notifications';

  @override
  String get enableNotifications => 'Enable notifications';

  @override
  String get next => 'Next';

  @override
  String get confirm => 'Confirm';

  @override
  String get search => 'Search';

  @override
  String get loading => 'Loading…';

  @override
  String get error => 'Something went wrong';

  @override
  String get retry => 'Retry';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get dailyLimitExceeded => 'Daily transaction limit exceeded';

  @override
  String get customerCardTitle => 'Customer card';

  @override
  String get customerInformation => 'Customer information';

  @override
  String get totalSpentLabel => 'Total spent';

  @override
  String get streakLabel => 'Streak';

  @override
  String get registeredOn => 'Registered on';

  @override
  String get blockedBadge => 'Blocked';

  @override
  String get customerNotFound => 'Customer not found';

  @override
  String get operationFailed => 'Operation failed — try again';

  @override
  String get sessionExpired => 'Session expired — sign in again';

  @override
  String get statTotalCustomers => 'Total customers';

  @override
  String get statStaffMembers => 'Staff';

  @override
  String get statTodayTransactionsCount => 'Today\'s transactions';

  @override
  String get statTodaySalesLabel => 'Today\'s sales';

  @override
  String get statTodayCashbackLabel => 'Today\'s cashback';

  @override
  String get currencyDisplay => 'SAR';

  @override
  String get customersTitle => 'Customers';

  @override
  String get navHome => 'Home';

  @override
  String get navPlans => 'Plans';

  @override
  String get tabScanner => 'Scanner';

  @override
  String get tabStore => 'Store';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleStaffMember => 'Staff';

  @override
  String get roleOwnerLabel => 'Owner';

  @override
  String get mainBranch => 'Main branch';

  @override
  String get mobilePhone => 'Mobile number';

  @override
  String get branchLabel => 'Branch';

  @override
  String get roleField => 'Role';

  @override
  String get statusField => 'Status';

  @override
  String get statusActive => 'Active';

  @override
  String get statusInactive => 'Inactive';

  @override
  String get staffCreatedOtpSent => 'Staff created — OTP sent to phone';

  @override
  String get pendingOfflineTooltip => 'Pending offline';

  @override
  String get phoneLabelShort => 'Phone';

  @override
  String get share => 'Share';

  @override
  String get loadMore => 'Load more';

  @override
  String get visits => 'Visits';

  @override
  String get lastVisit => 'Last visit';

  @override
  String get accountSettingsSubtitle => 'Account & settings';

  @override
  String get sectionInformation => 'Information';

  @override
  String get sectionPreferences => 'Preferences';

  @override
  String get tapToEditName => 'Tap to edit your name';

  @override
  String get contactUsTitle => 'Contact us';

  @override
  String get contactUsSubtitle => 'Branch info and phone numbers';

  @override
  String get branchesEmpty => 'No branches available';

  @override
  String get addressLabel => 'Address';

  @override
  String get whatsappLabel => 'WhatsApp';

  @override
  String get callAction => 'Call';

  @override
  String get whatsappAction => 'WhatsApp';

  @override
  String get teamSectionTitle => 'Our team';

  @override
  String get nameRequired => 'Please enter your name';

  @override
  String youEarned(String amount) {
    return 'You earned $amount';
  }

  @override
  String get registerYourName => 'Your name';

  @override
  String get registerFullNameHint => 'Full name';

  @override
  String get welcomeDialogTitle => 'Welcome! 🌟';

  @override
  String get welcomeDialogBody =>
      'We\'re glad you joined Point.\nEvery point means more savings 💙';

  @override
  String get welcomeGiftBadge => 'Welcome gift';

  @override
  String get welcomeGiftAmount => '10.00 SAR';

  @override
  String get welcomeGiftCaption => 'Free cashback in your wallet';

  @override
  String get welcomeGetStarted => 'Get started 🚀';

  @override
  String get homeBalanceReady => 'Your balance is ready';

  @override
  String get homeLoadErrorMessage => 'Something went wrong, try again';

  @override
  String get loadingTakingLong => 'Loading is taking longer than usual';

  @override
  String get addToWalletPrefix => 'Add to';

  @override
  String get addToGoogleWallet => 'Add to Google Wallet';

  @override
  String get addToAppleWallet => 'Add to Apple Wallet';

  @override
  String errorWithMessage(String message) {
    return 'Error: $message';
  }

  @override
  String get unknownError => 'Unknown';

  @override
  String get subscriptionShort => 'Subscription';

  @override
  String get planLabelPremium => 'Premium';

  @override
  String get planLabelDiamond => 'Diamond';

  @override
  String get planPayHeader => 'Pay';

  @override
  String get planGetHeader => 'Get';

  @override
  String savePercentLabel(String percent) {
    return 'Save $percent';
  }

  @override
  String get txTypeCashbackEarnedShort => 'Cashback';

  @override
  String get txTypeAdjustment => 'Adjustment';

  @override
  String get signInWithBiometrics => 'Sign in with biometrics / Face ID';

  @override
  String get biometricLoginTitle => 'Biometric sign-in';

  @override
  String get statusOn => 'Enabled';

  @override
  String get statusOff => 'Disabled';

  @override
  String get searchHint => 'Search…';

  @override
  String get fraudFlagSelfTx => 'Staff credited own phone';

  @override
  String get fraudFlagVelocity => 'Rapid repeated transactions';

  @override
  String get fraudFlagLarge => 'Large amount for review';

  @override
  String get fraudFlagDevice => 'Suspicious device';

  @override
  String get filterDormant => 'Dormant (30d)';

  @override
  String get reasonRequired => 'Reason (required)';

  @override
  String get staffListTitle => 'Staff';

  @override
  String get currentSubscriptionBalancePrefix =>
      'Current subscription balance:';

  @override
  String get totalColon => 'Total:';

  @override
  String get walletHowItWorks => 'How it works';

  @override
  String get walletStepPayCash => 'Pay with cash';

  @override
  String get walletStepCashback => 'Get 20% cashback';

  @override
  String get walletStepUseNext => 'Use it on your next visit';

  @override
  String get actionDeactivate => 'Deactivate';

  @override
  String get actionActivate => 'Activate';

  @override
  String get cashbackEarnedSuffix => 'cashback';

  @override
  String get staffSearchByPhone => 'Search by phone';

  @override
  String get staffScanCustomerQr => 'Scan the customer\'s QR code';

  @override
  String get staffFindCustomer => 'Find a customer';

  @override
  String get staffEnterNineDigits => 'Enter 9 digits';

  @override
  String get staffNoCustomerForPhone => 'No customer with this number';

  @override
  String get staffPickCustomer => 'Choose a customer:';

  @override
  String get staffOfflineTxSaved =>
      'No connection — transaction saved and will be sent automatically';

  @override
  String staffAmountSar(String amount) {
    return '$amount SAR';
  }

  @override
  String get staffSaudiRiyal => 'Saudi Riyal';

  @override
  String staffAvailableSar(String amount) {
    return 'Available: $amount SAR';
  }

  @override
  String staffCashbackPreviewPlus(String amount) {
    return '✨ Cashback: +$amount SAR';
  }

  @override
  String staffSummaryPurchAmountPaid(String amount) {
    return 'Amount paid: $amount';
  }

  @override
  String staffSummaryPurchCbAdded(String amount) {
    return 'Cashback added: +$amount';
  }

  @override
  String staffSummaryPurchCbAfter(String amount) {
    return 'Cashback balance after: $amount';
  }

  @override
  String staffSummaryRedeemAmount(String amount) {
    return 'Amount redeemed: $amount';
  }

  @override
  String staffSummaryRedeemFromSub(String amount) {
    return 'From subscription balance: $amount';
  }

  @override
  String staffSummaryRedeemFromCb(String amount) {
    return 'From cashback: $amount';
  }

  @override
  String staffSummaryRedeemWalletAfter(String amount) {
    return 'Wallet balance after: $amount';
  }

  @override
  String staffSubscriptionBalanceLine(String amount) {
    return 'Current subscription balance: $amount';
  }

  @override
  String staffPlanCustomerPaysCash(String amount) {
    return 'Customer pays: $amount cash';
  }

  @override
  String staffPlanCustomerGetsCredit(String amount) {
    return 'Gets: $amount credit';
  }

  @override
  String get staffConfirmAddSubscription => 'Confirm add subscription';

  @override
  String get staffTransactionCompleted => 'Transaction completed successfully!';

  @override
  String get staffUndoDialogTitle => 'Undo this transaction?';

  @override
  String get staffUndoDialogBody =>
      'The transaction will be reversed for the customer.';

  @override
  String get staffConfirmUndo => 'Confirm undo';

  @override
  String get staffTransactionUndone => 'Transaction undone';

  @override
  String get staffUndoShort => 'Undo';

  @override
  String get staffSuccCustomer => 'Customer';

  @override
  String get staffSuccAmountPaid => 'Amount paid';

  @override
  String get staffSuccCashbackAdded => 'Cashback added';

  @override
  String get staffSuccCashbackNow => 'Cashback balance now';

  @override
  String get staffSuccAmountRedeemed => 'Amount redeemed';

  @override
  String get staffSuccFromSubscription => 'From subscription';

  @override
  String get staffSuccFromCashback => 'From cashback';

  @override
  String get staffSuccSubAfter => 'Subscription balance after';

  @override
  String get staffSuccCashbackAfter => 'Cashback after';

  @override
  String get staffSuccPaidCash => 'Paid in cash';

  @override
  String get staffSuccCreditAdded => 'Credit added';

  @override
  String get staffSuccSubNow => 'Subscription balance now';
}
