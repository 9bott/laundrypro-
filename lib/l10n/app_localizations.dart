import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Point'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Count, earn, save'**
  String get tagline;

  /// No description provided for @enterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get enterPhone;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send verification code'**
  String get sendOtp;

  /// No description provided for @loginAsStaff.
  ///
  /// In en, this message translates to:
  /// **'Log in as staff'**
  String get loginAsStaff;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to {phone}'**
  String otpSentTo(String phone);

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive it? Resend'**
  String get resendOtp;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds} seconds'**
  String resendIn(int seconds);

  /// No description provided for @welcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcomeUser(String name);

  /// No description provided for @subscriptionBalance.
  ///
  /// In en, this message translates to:
  /// **'Subscription balance'**
  String get subscriptionBalance;

  /// No description provided for @cashbackBalance.
  ///
  /// In en, this message translates to:
  /// **'Cashback'**
  String get cashbackBalance;

  /// No description provided for @showQrToStaff.
  ///
  /// In en, this message translates to:
  /// **'Show this QR or give your phone number to staff'**
  String get showQrToStaff;

  /// No description provided for @qrRefreshIn.
  ///
  /// In en, this message translates to:
  /// **'Refreshes in: {seconds} seconds'**
  String qrRefreshIn(int seconds);

  /// No description provided for @staticLoyaltyQrHint.
  ///
  /// In en, this message translates to:
  /// **'Same code as your Google/Apple Wallet card'**
  String get staticLoyaltyQrHint;

  /// No description provided for @customerQrExpired.
  ///
  /// In en, this message translates to:
  /// **'This code expired — tap to refresh'**
  String get customerQrExpired;

  /// No description provided for @qrTokenServerConfigError.
  ///
  /// In en, this message translates to:
  /// **'Could not create your QR code: server not configured. In Edge Function secrets set SUPABASE_JWT_SECRET, or if blocked use QR_JWT_SECRET or SUPABASE1_JWT_SECRET, then deploy generate-qr-token.'**
  String get qrTokenServerConfigError;

  /// No description provided for @qrTokenAuthError.
  ///
  /// In en, this message translates to:
  /// **'Could not verify your account. Pull to refresh, or sign out and sign in again.'**
  String get qrTokenAuthError;

  /// No description provided for @orTellPhone.
  ///
  /// In en, this message translates to:
  /// **'Or tell staff your phone number:'**
  String get orTellPhone;

  /// No description provided for @myBalance.
  ///
  /// In en, this message translates to:
  /// **'My balance'**
  String get myBalance;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletTitle;

  /// No description provided for @walletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your loyalty card to your phone wallet.'**
  String get walletSubtitle;

  /// No description provided for @addToGoogleWallet.
  ///
  /// In en, this message translates to:
  /// **'Add to Google Wallet'**
  String get addToGoogleWallet;

  /// No description provided for @addToAppleWallet.
  ///
  /// In en, this message translates to:
  /// **'Add to Apple Wallet'**
  String get addToAppleWallet;

  /// No description provided for @appleWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Apple Wallet'**
  String get appleWalletTitle;

  /// No description provided for @appleWalletNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Apple Wallet is not enabled yet. It requires Apple Pass Type certificate setup.'**
  String get appleWalletNotEnabled;

  /// No description provided for @walletAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate wallet pass. Please try again.'**
  String get walletAddFailed;

  /// No description provided for @walletOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open wallet. Please try again.'**
  String get walletOpenFailed;

  /// No description provided for @usedFirst.
  ///
  /// In en, this message translates to:
  /// **'Used first when paying'**
  String get usedFirst;

  /// No description provided for @cashbackRate.
  ///
  /// In en, this message translates to:
  /// **'20% cashback on every purchase'**
  String get cashbackRate;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total: {amount} SAR'**
  String totalBalance(String amount);

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get transactionHistory;

  /// No description provided for @recentTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get recentTransactionsTitle;

  /// No description provided for @recentSubscriptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent subscriptions'**
  String get recentSubscriptionsTitle;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get filterPurchase;

  /// No description provided for @filterRedemption.
  ///
  /// In en, this message translates to:
  /// **'Redemption'**
  String get filterRedemption;

  /// No description provided for @filterSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get filterSubscription;

  /// No description provided for @filterBonus.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get filterBonus;

  /// No description provided for @noTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactions;

  /// No description provided for @nothingToShow.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show'**
  String get nothingToShow;

  /// No description provided for @subscriptionScreenSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the subscription plan that fits you'**
  String get subscriptionScreenSubtitle;

  /// No description provided for @balanceSubscriptionHelp.
  ///
  /// In en, this message translates to:
  /// **'Used first when paying'**
  String get balanceSubscriptionHelp;

  /// No description provided for @balanceCashbackHelp.
  ///
  /// In en, this message translates to:
  /// **'20% from every purchase'**
  String get balanceCashbackHelp;

  /// No description provided for @topUpBalance.
  ///
  /// In en, this message translates to:
  /// **'Top up balance'**
  String get topUpBalance;

  /// No description provided for @rechargeTagline.
  ///
  /// In en, this message translates to:
  /// **'Pay less, get more credit'**
  String get rechargeTagline;

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount} SAR'**
  String pay(String amount);

  /// No description provided for @get.
  ///
  /// In en, this message translates to:
  /// **'Get {amount} SAR credit'**
  String get(String amount);

  /// No description provided for @mostPopular.
  ///
  /// In en, this message translates to:
  /// **'Most popular'**
  String get mostPopular;

  /// No description provided for @howToBuy.
  ///
  /// In en, this message translates to:
  /// **'How to buy?'**
  String get howToBuy;

  /// No description provided for @howToBuyStep1.
  ///
  /// In en, this message translates to:
  /// **'Tell staff which plan you want'**
  String get howToBuyStep1;

  /// No description provided for @howToBuyStep2.
  ///
  /// In en, this message translates to:
  /// **'Pay cash to staff'**
  String get howToBuyStep2;

  /// No description provided for @howToBuyStep3.
  ///
  /// In en, this message translates to:
  /// **'Staff will add credit to your account instantly'**
  String get howToBuyStep3;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @referralCode.
  ///
  /// In en, this message translates to:
  /// **'Your referral code'**
  String get referralCode;

  /// No description provided for @referralShare.
  ///
  /// In en, this message translates to:
  /// **'Join me on Point and get 5 SAR! Use my code: {code}'**
  String referralShare(String code);

  /// No description provided for @referredCount.
  ///
  /// In en, this message translates to:
  /// **'Referrals: {count} people'**
  String referredCount(int count);

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get enterPin;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get wrongPin;

  /// No description provided for @lockedOut.
  ///
  /// In en, this message translates to:
  /// **'Locked. Try again in {minutes} minutes'**
  String lockedOut(int minutes);

  /// No description provided for @scanQr.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the customer QR'**
  String get scanQr;

  /// No description provided for @enterPhone2.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get enterPhone2;

  /// No description provided for @qrExpired.
  ///
  /// In en, this message translates to:
  /// **'QR expired — ask the customer to refresh it'**
  String get qrExpired;

  /// No description provided for @invalidQr.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR'**
  String get invalidQr;

  /// No description provided for @recordPurchase.
  ///
  /// In en, this message translates to:
  /// **'Record purchase'**
  String get recordPurchase;

  /// No description provided for @redeemBalance.
  ///
  /// In en, this message translates to:
  /// **'Redeem balance'**
  String get redeemBalance;

  /// No description provided for @addSubscription.
  ///
  /// In en, this message translates to:
  /// **'Add subscription'**
  String get addSubscription;

  /// No description provided for @addsCashback.
  ///
  /// In en, this message translates to:
  /// **'Adds 20% cashback'**
  String get addsCashback;

  /// No description provided for @deductsFromBalance.
  ///
  /// In en, this message translates to:
  /// **'Deducts from customer balance'**
  String get deductsFromBalance;

  /// No description provided for @topUpWithCash.
  ///
  /// In en, this message translates to:
  /// **'Top up balance with cash'**
  String get topUpWithCash;

  /// No description provided for @visitNumber.
  ///
  /// In en, this message translates to:
  /// **'Visit #{count}'**
  String visitNumber(int count);

  /// No description provided for @cashPaid.
  ///
  /// In en, this message translates to:
  /// **'Cash paid'**
  String get cashPaid;

  /// No description provided for @cashbackAdded.
  ///
  /// In en, this message translates to:
  /// **'Cashback added'**
  String get cashbackAdded;

  /// No description provided for @balanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Balance after transaction'**
  String get balanceAfter;

  /// No description provided for @amountRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Amount redeemed'**
  String get amountRedeemed;

  /// No description provided for @fromSubscription.
  ///
  /// In en, this message translates to:
  /// **'From subscription balance'**
  String get fromSubscription;

  /// No description provided for @fromCashback.
  ///
  /// In en, this message translates to:
  /// **'From cashback'**
  String get fromCashback;

  /// No description provided for @remainingBalance.
  ///
  /// In en, this message translates to:
  /// **'Remaining balance'**
  String get remainingBalance;

  /// No description provided for @confirmOperation.
  ///
  /// In en, this message translates to:
  /// **'Confirm transaction'**
  String get confirmOperation;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @operationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get operationSuccess;

  /// No description provided for @smsSent.
  ///
  /// In en, this message translates to:
  /// **'SMS sent to customer'**
  String get smsSent;

  /// No description provided for @returningIn.
  ///
  /// In en, this message translates to:
  /// **'Returning to camera in: {seconds}'**
  String returningIn(int seconds);

  /// No description provided for @undoOperation.
  ///
  /// In en, this message translates to:
  /// **'Undo transaction'**
  String get undoOperation;

  /// No description provided for @undoAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available for: {seconds} seconds'**
  String undoAvailable(int seconds);

  /// No description provided for @cashbackPreview.
  ///
  /// In en, this message translates to:
  /// **'Customer earns: {amount} SAR cashback'**
  String cashbackPreview(String amount);

  /// No description provided for @insufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get insufficientBalance;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available: {amount} SAR'**
  String available(String amount);

  /// No description provided for @confirmCashReceived.
  ///
  /// In en, this message translates to:
  /// **'Confirm you received cash before adding subscription'**
  String get confirmCashReceived;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get offlineBanner;

  /// No description provided for @pendingTransactions.
  ///
  /// In en, this message translates to:
  /// **'{count} pending transactions'**
  String pendingTransactions(int count);

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @newCustomers.
  ///
  /// In en, this message translates to:
  /// **'New customers'**
  String get newCustomers;

  /// No description provided for @cashbackIssued.
  ///
  /// In en, this message translates to:
  /// **'Cashback issued'**
  String get cashbackIssued;

  /// No description provided for @subscriptionsSold.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions sold'**
  String get subscriptionsSold;

  /// No description provided for @fraudAlerts.
  ///
  /// In en, this message translates to:
  /// **'Fraud alerts'**
  String get fraudAlerts;

  /// No description provided for @topCustomers.
  ///
  /// In en, this message translates to:
  /// **'Top customers'**
  String get topCustomers;

  /// No description provided for @staffActivity.
  ///
  /// In en, this message translates to:
  /// **'Staff activity'**
  String get staffActivity;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @adjustBalance.
  ///
  /// In en, this message translates to:
  /// **'Adjust balance'**
  String get adjustBalance;

  /// No description provided for @blockCustomer.
  ///
  /// In en, this message translates to:
  /// **'Block customer'**
  String get blockCustomer;

  /// No description provided for @unblockCustomer.
  ///
  /// In en, this message translates to:
  /// **'Unblock customer'**
  String get unblockCustomer;

  /// No description provided for @inviteStaff.
  ///
  /// In en, this message translates to:
  /// **'Invite new staff'**
  String get inviteStaff;

  /// No description provided for @deactivateStaff.
  ///
  /// In en, this message translates to:
  /// **'Deactivate account'**
  String get deactivateStaff;

  /// No description provided for @markReviewed.
  ///
  /// In en, this message translates to:
  /// **'Mark reviewed'**
  String get markReviewed;

  /// No description provided for @reverseTransaction.
  ///
  /// In en, this message translates to:
  /// **'Reverse transaction'**
  String get reverseTransaction;

  /// No description provided for @bronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze'**
  String get bronze;

  /// No description provided for @silver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get silver;

  /// No description provided for @gold.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get gold;

  /// No description provided for @sarSuffix.
  ///
  /// In en, this message translates to:
  /// **' SAR'**
  String get sarSuffix;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @bengali.
  ///
  /// In en, this message translates to:
  /// **'Bengali'**
  String get bengali;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterName;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @idLabel.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get idLabel;

  /// No description provided for @birthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get birthday;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get enableNotifications;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @dailyLimitExceeded.
  ///
  /// In en, this message translates to:
  /// **'Daily transaction limit exceeded'**
  String get dailyLimitExceeded;

  /// No description provided for @customerCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer card'**
  String get customerCardTitle;

  /// No description provided for @customerInformation.
  ///
  /// In en, this message translates to:
  /// **'Customer information'**
  String get customerInformation;

  /// No description provided for @totalSpentLabel.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get totalSpentLabel;

  /// No description provided for @streakLabel.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get streakLabel;

  /// No description provided for @registeredOn.
  ///
  /// In en, this message translates to:
  /// **'Registered on'**
  String get registeredOn;

  /// No description provided for @blockedBadge.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blockedBadge;

  /// No description provided for @customerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Customer not found'**
  String get customerNotFound;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed — try again'**
  String get operationFailed;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired — sign in again'**
  String get sessionExpired;

  /// No description provided for @statTotalCustomers.
  ///
  /// In en, this message translates to:
  /// **'Total customers'**
  String get statTotalCustomers;

  /// No description provided for @statStaffMembers.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get statStaffMembers;

  /// No description provided for @statTodayTransactionsCount.
  ///
  /// In en, this message translates to:
  /// **'Today\'s transactions'**
  String get statTodayTransactionsCount;

  /// No description provided for @statTodaySalesLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sales'**
  String get statTodaySalesLabel;

  /// No description provided for @statTodayCashbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s cashback'**
  String get statTodayCashbackLabel;

  /// No description provided for @currencyDisplay.
  ///
  /// In en, this message translates to:
  /// **'SAR'**
  String get currencyDisplay;

  /// No description provided for @customersTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get navPlans;

  /// No description provided for @tabScanner.
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get tabScanner;

  /// No description provided for @tabStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get tabStore;

  /// No description provided for @roleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get roleManager;

  /// No description provided for @roleStaffMember.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get roleStaffMember;

  /// No description provided for @roleOwnerLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get roleOwnerLabel;

  /// No description provided for @mainBranch.
  ///
  /// In en, this message translates to:
  /// **'Main branch'**
  String get mainBranch;

  /// No description provided for @mobilePhone.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get mobilePhone;

  /// No description provided for @branchLabel.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branchLabel;

  /// No description provided for @roleField.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get roleField;

  /// No description provided for @statusField.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusField;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get statusInactive;

  /// No description provided for @staffCreatedOtpSent.
  ///
  /// In en, this message translates to:
  /// **'Staff created — OTP sent to phone'**
  String get staffCreatedOtpSent;

  /// No description provided for @pendingOfflineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pending offline'**
  String get pendingOfflineTooltip;

  /// No description provided for @phoneLabelShort.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phoneLabelShort;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @visits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visits;

  /// No description provided for @lastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit'**
  String get lastVisit;

  /// No description provided for @accountSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Account & settings'**
  String get accountSettingsSubtitle;

  /// No description provided for @sectionInformation.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get sectionInformation;

  /// No description provided for @sectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get sectionPreferences;

  /// No description provided for @tapToEditName.
  ///
  /// In en, this message translates to:
  /// **'Tap to edit your name'**
  String get tapToEditName;

  /// No description provided for @contactUsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactUsTitle;

  /// No description provided for @contactUsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Branch info and phone numbers'**
  String get contactUsSubtitle;

  /// No description provided for @branchesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No branches available'**
  String get branchesEmpty;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel;

  /// No description provided for @whatsappLabel.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsappLabel;

  /// No description provided for @callAction.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callAction;

  /// No description provided for @whatsappAction.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsappAction;

  /// No description provided for @teamSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Our team'**
  String get teamSectionTitle;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get nameRequired;

  /// No description provided for @youEarned.
  ///
  /// In en, this message translates to:
  /// **'You earned {amount}'**
  String youEarned(String amount);

  /// No description provided for @registerYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get registerYourName;

  /// No description provided for @registerFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get registerFullNameHint;

  /// No description provided for @welcomeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome! 🌟'**
  String get welcomeDialogTitle;

  /// No description provided for @welcomeDialogBody.
  ///
  /// In en, this message translates to:
  /// **'We\'re glad you joined Point.\nEvery point means more savings 💙'**
  String get welcomeDialogBody;

  /// No description provided for @welcomeGiftBadge.
  ///
  /// In en, this message translates to:
  /// **'Welcome gift'**
  String get welcomeGiftBadge;

  /// No description provided for @welcomeGiftAmount.
  ///
  /// In en, this message translates to:
  /// **'10.00 SAR'**
  String get welcomeGiftAmount;

  /// No description provided for @welcomeGiftCaption.
  ///
  /// In en, this message translates to:
  /// **'Free cashback in your account'**
  String get welcomeGiftCaption;

  /// No description provided for @welcomeGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started 🚀'**
  String get welcomeGetStarted;

  /// No description provided for @homeBalanceReady.
  ///
  /// In en, this message translates to:
  /// **'Your balance is ready'**
  String get homeBalanceReady;

  /// No description provided for @homeLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong, try again'**
  String get homeLoadErrorMessage;

  /// No description provided for @loadingTakingLong.
  ///
  /// In en, this message translates to:
  /// **'Loading is taking longer than usual'**
  String get loadingTakingLong;

  /// No description provided for @errorWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorWithMessage(String message);

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownError;

  /// No description provided for @subscriptionShort.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscriptionShort;

  /// No description provided for @planLabelPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get planLabelPremium;

  /// No description provided for @planLabelDiamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get planLabelDiamond;

  /// No description provided for @planPayHeader.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get planPayHeader;

  /// No description provided for @planGetHeader.
  ///
  /// In en, this message translates to:
  /// **'Get'**
  String get planGetHeader;

  /// No description provided for @savePercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Save {percent}'**
  String savePercentLabel(String percent);

  /// No description provided for @txTypeCashbackEarnedShort.
  ///
  /// In en, this message translates to:
  /// **'Cashback'**
  String get txTypeCashbackEarnedShort;

  /// No description provided for @txTypeAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get txTypeAdjustment;

  /// No description provided for @signInWithBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Sign in with biometrics / Face ID'**
  String get signInWithBiometrics;

  /// No description provided for @biometricLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Biometric sign-in'**
  String get biometricLoginTitle;

  /// No description provided for @statusOn.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get statusOn;

  /// No description provided for @statusOff.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get statusOff;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get searchHint;

  /// No description provided for @fraudFlagSelfTx.
  ///
  /// In en, this message translates to:
  /// **'Staff credited own phone'**
  String get fraudFlagSelfTx;

  /// No description provided for @fraudFlagVelocity.
  ///
  /// In en, this message translates to:
  /// **'Rapid repeated transactions'**
  String get fraudFlagVelocity;

  /// No description provided for @fraudFlagLarge.
  ///
  /// In en, this message translates to:
  /// **'Large amount for review'**
  String get fraudFlagLarge;

  /// No description provided for @fraudFlagDevice.
  ///
  /// In en, this message translates to:
  /// **'Suspicious device'**
  String get fraudFlagDevice;

  /// No description provided for @filterDormant.
  ///
  /// In en, this message translates to:
  /// **'Dormant (30d)'**
  String get filterDormant;

  /// No description provided for @reasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Reason (required)'**
  String get reasonRequired;

  /// No description provided for @staffListTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get staffListTitle;

  /// No description provided for @currentSubscriptionBalancePrefix.
  ///
  /// In en, this message translates to:
  /// **'Current subscription balance:'**
  String get currentSubscriptionBalancePrefix;

  /// No description provided for @totalColon.
  ///
  /// In en, this message translates to:
  /// **'Total:'**
  String get totalColon;

  /// No description provided for @balanceHowItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get balanceHowItWorks;

  /// No description provided for @balanceStepPayCash.
  ///
  /// In en, this message translates to:
  /// **'Pay with cash'**
  String get balanceStepPayCash;

  /// No description provided for @balanceStepCashback.
  ///
  /// In en, this message translates to:
  /// **'Get 20% cashback'**
  String get balanceStepCashback;

  /// No description provided for @balanceStepUseNext.
  ///
  /// In en, this message translates to:
  /// **'Use it on your next visit'**
  String get balanceStepUseNext;

  /// No description provided for @staffSummaryRedeemBalanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Balance after: {amount}'**
  String staffSummaryRedeemBalanceAfter(String amount);

  /// No description provided for @actionDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get actionDeactivate;

  /// No description provided for @actionActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get actionActivate;

  /// No description provided for @cashbackEarnedSuffix.
  ///
  /// In en, this message translates to:
  /// **'cashback'**
  String get cashbackEarnedSuffix;

  /// No description provided for @staffSearchByPhone.
  ///
  /// In en, this message translates to:
  /// **'Search by phone'**
  String get staffSearchByPhone;

  /// No description provided for @staffScanCustomerQr.
  ///
  /// In en, this message translates to:
  /// **'Scan the customer\'s QR code'**
  String get staffScanCustomerQr;

  /// No description provided for @staffFindCustomer.
  ///
  /// In en, this message translates to:
  /// **'Find a customer'**
  String get staffFindCustomer;

  /// No description provided for @staffEnterNineDigits.
  ///
  /// In en, this message translates to:
  /// **'Enter 9 digits'**
  String get staffEnterNineDigits;

  /// No description provided for @staffNoCustomerForPhone.
  ///
  /// In en, this message translates to:
  /// **'No customer with this number'**
  String get staffNoCustomerForPhone;

  /// No description provided for @staffPickCustomer.
  ///
  /// In en, this message translates to:
  /// **'Choose a customer:'**
  String get staffPickCustomer;

  /// No description provided for @staffOfflineTxSaved.
  ///
  /// In en, this message translates to:
  /// **'No connection — transaction saved and will be sent automatically'**
  String get staffOfflineTxSaved;

  /// No description provided for @staffAmountSar.
  ///
  /// In en, this message translates to:
  /// **'{amount} SAR'**
  String staffAmountSar(String amount);

  /// No description provided for @staffSaudiRiyal.
  ///
  /// In en, this message translates to:
  /// **'Saudi Riyal'**
  String get staffSaudiRiyal;

  /// No description provided for @staffAvailableSar.
  ///
  /// In en, this message translates to:
  /// **'Available: {amount} SAR'**
  String staffAvailableSar(String amount);

  /// No description provided for @staffCashbackPreviewPlus.
  ///
  /// In en, this message translates to:
  /// **'✨ Cashback: +{amount} SAR'**
  String staffCashbackPreviewPlus(String amount);

  /// No description provided for @staffSummaryPurchAmountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount paid: {amount}'**
  String staffSummaryPurchAmountPaid(String amount);

  /// No description provided for @staffSummaryPurchCbAdded.
  ///
  /// In en, this message translates to:
  /// **'Cashback added: +{amount}'**
  String staffSummaryPurchCbAdded(String amount);

  /// No description provided for @staffSummaryPurchCbAfter.
  ///
  /// In en, this message translates to:
  /// **'Cashback balance after: {amount}'**
  String staffSummaryPurchCbAfter(String amount);

  /// No description provided for @staffSummaryRedeemAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount redeemed: {amount}'**
  String staffSummaryRedeemAmount(String amount);

  /// No description provided for @staffSummaryRedeemFromSub.
  ///
  /// In en, this message translates to:
  /// **'From subscription balance: {amount}'**
  String staffSummaryRedeemFromSub(String amount);

  /// No description provided for @staffSummaryRedeemFromCb.
  ///
  /// In en, this message translates to:
  /// **'From cashback: {amount}'**
  String staffSummaryRedeemFromCb(String amount);

  /// No description provided for @staffSubscriptionBalanceLine.
  ///
  /// In en, this message translates to:
  /// **'Current subscription balance: {amount}'**
  String staffSubscriptionBalanceLine(String amount);

  /// No description provided for @staffPlanCustomerPaysCash.
  ///
  /// In en, this message translates to:
  /// **'Customer pays: {amount} cash'**
  String staffPlanCustomerPaysCash(String amount);

  /// No description provided for @staffPlanCustomerGetsCredit.
  ///
  /// In en, this message translates to:
  /// **'Gets: {amount} credit'**
  String staffPlanCustomerGetsCredit(String amount);

  /// No description provided for @staffConfirmAddSubscription.
  ///
  /// In en, this message translates to:
  /// **'Confirm add subscription'**
  String get staffConfirmAddSubscription;

  /// No description provided for @staffTransactionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Transaction completed successfully!'**
  String get staffTransactionCompleted;

  /// No description provided for @staffUndoDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Undo this transaction?'**
  String get staffUndoDialogTitle;

  /// No description provided for @staffUndoDialogBody.
  ///
  /// In en, this message translates to:
  /// **'The transaction will be reversed for the customer.'**
  String get staffUndoDialogBody;

  /// No description provided for @staffConfirmUndo.
  ///
  /// In en, this message translates to:
  /// **'Confirm undo'**
  String get staffConfirmUndo;

  /// No description provided for @staffTransactionUndone.
  ///
  /// In en, this message translates to:
  /// **'Transaction undone'**
  String get staffTransactionUndone;

  /// No description provided for @staffUndoShort.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get staffUndoShort;

  /// No description provided for @staffSuccCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get staffSuccCustomer;

  /// No description provided for @staffSuccAmountPaid.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get staffSuccAmountPaid;

  /// No description provided for @staffSuccCashbackAdded.
  ///
  /// In en, this message translates to:
  /// **'Cashback added'**
  String get staffSuccCashbackAdded;

  /// No description provided for @staffSuccCashbackNow.
  ///
  /// In en, this message translates to:
  /// **'Cashback balance now'**
  String get staffSuccCashbackNow;

  /// No description provided for @staffSuccAmountRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Amount redeemed'**
  String get staffSuccAmountRedeemed;

  /// No description provided for @staffSuccFromSubscription.
  ///
  /// In en, this message translates to:
  /// **'From subscription'**
  String get staffSuccFromSubscription;

  /// No description provided for @staffSuccFromCashback.
  ///
  /// In en, this message translates to:
  /// **'From cashback'**
  String get staffSuccFromCashback;

  /// No description provided for @staffSuccSubAfter.
  ///
  /// In en, this message translates to:
  /// **'Subscription balance after'**
  String get staffSuccSubAfter;

  /// No description provided for @staffSuccCashbackAfter.
  ///
  /// In en, this message translates to:
  /// **'Cashback after'**
  String get staffSuccCashbackAfter;

  /// No description provided for @staffSuccPaidCash.
  ///
  /// In en, this message translates to:
  /// **'Paid in cash'**
  String get staffSuccPaidCash;

  /// No description provided for @staffSuccCreditAdded.
  ///
  /// In en, this message translates to:
  /// **'Credit added'**
  String get staffSuccCreditAdded;

  /// No description provided for @staffSuccSubNow.
  ///
  /// In en, this message translates to:
  /// **'Subscription balance now'**
  String get staffSuccSubNow;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
