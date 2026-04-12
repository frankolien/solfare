import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

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
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Solfare'**
  String get appName;

  /// No description provided for @portfolio.
  ///
  /// In en, this message translates to:
  /// **'Portfolio'**
  String get portfolio;

  /// No description provided for @market.
  ///
  /// In en, this message translates to:
  /// **'Market'**
  String get market;

  /// No description provided for @swap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get swap;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @mainWallet.
  ///
  /// In en, this message translates to:
  /// **'Main Wallet'**
  String get mainWallet;

  /// No description provided for @mw.
  ///
  /// In en, this message translates to:
  /// **'MW'**
  String get mw;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'BALANCE'**
  String get balance;

  /// No description provided for @deposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get deposit;

  /// No description provided for @stake.
  ///
  /// In en, this message translates to:
  /// **'Stake'**
  String get stake;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @tokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get tokens;

  /// No description provided for @stocks.
  ///
  /// In en, this message translates to:
  /// **'Stocks'**
  String get stocks;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @solana.
  ///
  /// In en, this message translates to:
  /// **'Solana'**
  String get solana;

  /// No description provided for @customizePortfolio.
  ///
  /// In en, this message translates to:
  /// **'Customize portfolio'**
  String get customizePortfolio;

  /// No description provided for @noAssetsYet.
  ///
  /// In en, this message translates to:
  /// **'No assets yet'**
  String get noAssetsYet;

  /// No description provided for @noSolStaked.
  ///
  /// In en, this message translates to:
  /// **'No SOL staked yet'**
  String get noSolStaked;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get transactionHistory;

  /// No description provided for @staking.
  ///
  /// In en, this message translates to:
  /// **'Staking'**
  String get staking;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @startStaking.
  ///
  /// In en, this message translates to:
  /// **'Start staking'**
  String get startStaking;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @getStartedWithSol.
  ///
  /// In en, this message translates to:
  /// **'Get Started With SOL'**
  String get getStartedWithSol;

  /// No description provided for @getStartedDescDevnet.
  ///
  /// In en, this message translates to:
  /// **'Request free test SOL on devnet to start trading, staking, and exploring. You\'ll need a tiny amount of SOL for each Solana transaction.'**
  String get getStartedDescDevnet;

  /// No description provided for @getStartedDescMainnet.
  ///
  /// In en, this message translates to:
  /// **'Buy SOL to start trading, staking, and exploring. You\'ll need a tiny amount of SOL for each Solana transaction.'**
  String get getStartedDescMainnet;

  /// No description provided for @requestTestSol.
  ///
  /// In en, this message translates to:
  /// **'Request Test SOL'**
  String get requestTestSol;

  /// No description provided for @buySol.
  ///
  /// In en, this message translates to:
  /// **'Buy SOL'**
  String get buySol;

  /// No description provided for @airdropRequested.
  ///
  /// In en, this message translates to:
  /// **'Airdrop requested! Balance will update shortly.'**
  String get airdropRequested;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorPrefix(Object message);

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @editLanguageCurrency.
  ///
  /// In en, this message translates to:
  /// **'Edit language and currency'**
  String get editLanguageCurrency;

  /// No description provided for @addressBook.
  ///
  /// In en, this message translates to:
  /// **'Address book'**
  String get addressBook;

  /// No description provided for @manageContacts.
  ///
  /// In en, this message translates to:
  /// **'Manage your contacts'**
  String get manageContacts;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @getImportantUpdates.
  ///
  /// In en, this message translates to:
  /// **'Get important updates'**
  String get getImportantUpdates;

  /// No description provided for @securityPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Security & privacy'**
  String get securityPrivacy;

  /// No description provided for @manageAppsMore.
  ///
  /// In en, this message translates to:
  /// **'Manage apps and more'**
  String get manageAppsMore;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact our customer support'**
  String get contactSupport;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(Object version);

  /// No description provided for @resetWallet.
  ///
  /// In en, this message translates to:
  /// **'Reset Wallet'**
  String get resetWallet;

  /// No description provided for @resetWalletWarning.
  ///
  /// In en, this message translates to:
  /// **'This will remove all wallet data from this device. Make sure you have your recovery phrase backed up.'**
  String get resetWalletWarning;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @usDollar.
  ///
  /// In en, this message translates to:
  /// **'US Dollar'**
  String get usDollar;

  /// No description provided for @network.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get network;

  /// No description provided for @devnet.
  ///
  /// In en, this message translates to:
  /// **'Devnet'**
  String get devnet;

  /// No description provided for @mainnet.
  ///
  /// In en, this message translates to:
  /// **'Mainnet'**
  String get mainnet;

  /// No description provided for @securityPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Security & Privacy'**
  String get securityPrivacyTitle;

  /// No description provided for @manageApps.
  ///
  /// In en, this message translates to:
  /// **'Manage apps'**
  String get manageApps;

  /// No description provided for @appsConnectedPreviously.
  ///
  /// In en, this message translates to:
  /// **'Apps you connected to previously'**
  String get appsConnectedPreviously;

  /// No description provided for @spendingApprovals.
  ///
  /// In en, this message translates to:
  /// **'Spending approvals'**
  String get spendingApprovals;

  /// No description provided for @controlSpendAssets.
  ///
  /// In en, this message translates to:
  /// **'Control who can spend your assets'**
  String get controlSpendAssets;

  /// No description provided for @magicAi.
  ///
  /// In en, this message translates to:
  /// **'Magic AI'**
  String get magicAi;

  /// No description provided for @showMagicAssistant.
  ///
  /// In en, this message translates to:
  /// **'Show Magic assistant in the app'**
  String get showMagicAssistant;

  /// No description provided for @biometrics.
  ///
  /// In en, this message translates to:
  /// **'Biometrics'**
  String get biometrics;

  /// No description provided for @unlockQuickly.
  ///
  /// In en, this message translates to:
  /// **'Unlock the app quickly and securely'**
  String get unlockQuickly;

  /// No description provided for @changePasscode.
  ///
  /// In en, this message translates to:
  /// **'Change passcode'**
  String get changePasscode;

  /// No description provided for @updateAccountSecurity.
  ///
  /// In en, this message translates to:
  /// **'Update your account security'**
  String get updateAccountSecurity;

  /// No description provided for @requestAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Request authentication'**
  String get requestAuthentication;

  /// No description provided for @twentyFourHours.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get twentyFourHours;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @reviewRulesPolicies.
  ///
  /// In en, this message translates to:
  /// **'Review rules and policies'**
  String get reviewRulesPolicies;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @learnDataProtection.
  ///
  /// In en, this message translates to:
  /// **'Learn how we use and protect data'**
  String get learnDataProtection;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @removeAllWallets.
  ///
  /// In en, this message translates to:
  /// **'Remove all wallets and clear all data'**
  String get removeAllWallets;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add Contact'**
  String get addContact;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @walletAddress.
  ///
  /// In en, this message translates to:
  /// **'Wallet address'**
  String get walletAddress;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @contacts.
  ///
  /// In en, this message translates to:
  /// **'CONTACTS'**
  String get contacts;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'RECENT'**
  String get recent;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @noContactsYet.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet'**
  String get noContactsYet;

  /// No description provided for @yourRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Your recovery phrase'**
  String get yourRecoveryPhrase;

  /// No description provided for @writeItDown.
  ///
  /// In en, this message translates to:
  /// **'Write it down'**
  String get writeItDown;

  /// No description provided for @recoveryWarning.
  ///
  /// In en, this message translates to:
  /// **'Make sure no one is watching, this phrase gives full access to your wallet. Never share it with anyone.'**
  String get recoveryWarning;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @continueBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueBtn;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @confirmRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Confirm recovery phrase'**
  String get confirmRecoveryPhrase;

  /// No description provided for @whatIsWordNumber.
  ///
  /// In en, this message translates to:
  /// **'What is the {number} word in your recovery phrase?'**
  String whatIsWordNumber(Object number);

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get correct;

  /// No description provided for @oopsTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Oops, try again!'**
  String get oopsTryAgain;

  /// No description provided for @justMoreWords.
  ///
  /// In en, this message translates to:
  /// **'Just {count} more word{plural} and you are all set.'**
  String justMoreWords(Object count, Object plural);

  /// No description provided for @allDoneWalletReady.
  ///
  /// In en, this message translates to:
  /// **'All done! Your wallet is ready.'**
  String get allDoneWalletReady;

  /// No description provided for @goBackCheckPhrase.
  ///
  /// In en, this message translates to:
  /// **'You might want to go back and make sure you have written down the recovery phrase correctly.'**
  String get goBackCheckPhrase;

  /// No description provided for @keysToYourKingdom.
  ///
  /// In en, this message translates to:
  /// **'Keys to Your Kingdom'**
  String get keysToYourKingdom;

  /// No description provided for @keysDesc.
  ///
  /// In en, this message translates to:
  /// **'You\'ll get a recovery phrase—a unique set of 12 words that only you should know.'**
  String get keysDesc;

  /// No description provided for @getPenPaper.
  ///
  /// In en, this message translates to:
  /// **'Get Pen & Paper'**
  String get getPenPaper;

  /// No description provided for @penPaperDesc.
  ///
  /// In en, this message translates to:
  /// **'Your recovery phrase is safest when written on paper and stored in a secure place.'**
  String get penPaperDesc;

  /// No description provided for @writeItDownTitle.
  ///
  /// In en, this message translates to:
  /// **'Write it Down'**
  String get writeItDownTitle;

  /// No description provided for @writeItDownDesc.
  ///
  /// In en, this message translates to:
  /// **'Make sure no one is watching—this phrase gives full access to your wallet. Never share it with anyone.'**
  String get writeItDownDesc;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @enterRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Enter your recovery phrase'**
  String get enterRecoveryPhrase;

  /// No description provided for @analyzingWallets.
  ///
  /// In en, this message translates to:
  /// **'Analyzing wallets'**
  String get analyzingWallets;

  /// No description provided for @importWallets.
  ///
  /// In en, this message translates to:
  /// **'Import wallets'**
  String get importWallets;

  /// No description provided for @typeRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Type your recovery phrase'**
  String get typeRecoveryPhrase;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @invalidPhraseError.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid 12 or 24 word recovery phrase'**
  String get invalidPhraseError;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @walletImported.
  ///
  /// In en, this message translates to:
  /// **'Wallet imported'**
  String get walletImported;

  /// No description provided for @noActiveWallets.
  ///
  /// In en, this message translates to:
  /// **'No active wallets found'**
  String get noActiveWallets;

  /// No description provided for @quickSetup.
  ///
  /// In en, this message translates to:
  /// **'Quick setup'**
  String get quickSetup;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @enterNewPasscode.
  ///
  /// In en, this message translates to:
  /// **'Enter New Passcode'**
  String get enterNewPasscode;

  /// No description provided for @confirmPasscode.
  ///
  /// In en, this message translates to:
  /// **'Confirm Passcode'**
  String get confirmPasscode;

  /// No description provided for @enterPasscode.
  ///
  /// In en, this message translates to:
  /// **'Enter Passcode'**
  String get enterPasscode;

  /// No description provided for @unlockQuicker.
  ///
  /// In en, this message translates to:
  /// **'Unlock Quicker'**
  String get unlockQuicker;

  /// No description provided for @unlockBiometricDesc.
  ///
  /// In en, this message translates to:
  /// **'Unlock the app with your face or fingerprint, no passcode typing required.'**
  String get unlockBiometricDesc;

  /// No description provided for @enableBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Enable biometrics'**
  String get enableBiometrics;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @selectRecipient.
  ///
  /// In en, this message translates to:
  /// **'Select recipient'**
  String get selectRecipient;

  /// No description provided for @sendTo.
  ///
  /// In en, this message translates to:
  /// **'Send to'**
  String get sendTo;

  /// No description provided for @selectOrPasteAddress.
  ///
  /// In en, this message translates to:
  /// **'Select or paste address'**
  String get selectOrPasteAddress;

  /// No description provided for @newContact.
  ///
  /// In en, this message translates to:
  /// **'New contact'**
  String get newContact;

  /// No description provided for @slideToApprove.
  ///
  /// In en, this message translates to:
  /// **'Slide to approve'**
  String get slideToApprove;

  /// No description provided for @networkFee.
  ///
  /// In en, this message translates to:
  /// **'Network fee'**
  String get networkFee;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @safeToCloseScreen.
  ///
  /// In en, this message translates to:
  /// **'You can safely close this screen'**
  String get safeToCloseScreen;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get sending;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @transactionIdCopied.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID copied'**
  String get transactionIdCopied;

  /// No description provided for @transactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get transactionId;

  /// No description provided for @explorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get explorer;

  /// No description provided for @saveAddress.
  ///
  /// In en, this message translates to:
  /// **'Save address'**
  String get saveAddress;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get public;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsYet;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get today;

  /// No description provided for @sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @toAddress.
  ///
  /// In en, this message translates to:
  /// **'To: {address}'**
  String toAddress(Object address);

  /// No description provided for @fromAddress.
  ///
  /// In en, this message translates to:
  /// **'From: {address}'**
  String fromAddress(Object address);

  /// No description provided for @viewOnExplorer.
  ///
  /// In en, this message translates to:
  /// **'View on explorer'**
  String get viewOnExplorer;

  /// No description provided for @copyTransactionId.
  ///
  /// In en, this message translates to:
  /// **'Copy transaction ID'**
  String get copyTransactionId;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'DATE'**
  String get date;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get details;

  /// No description provided for @transactionResult.
  ///
  /// In en, this message translates to:
  /// **'TRANSACTION RESULT'**
  String get transactionResult;

  /// No description provided for @networkFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'NETWORK FEE'**
  String get networkFeeLabel;

  /// No description provided for @transactionIdLabel.
  ///
  /// In en, this message translates to:
  /// **'TRANSACTION ID'**
  String get transactionIdLabel;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied — open in browser'**
  String get linkCopied;

  /// No description provided for @youreAllSet.
  ///
  /// In en, this message translates to:
  /// **'You\'re All Set'**
  String get youreAllSet;

  /// No description provided for @walletSecuredDesc.
  ///
  /// In en, this message translates to:
  /// **'Your wallet is secured, and only you hold the keys. Start exploring your kingdom!'**
  String get walletSecuredDesc;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @marketCap.
  ///
  /// In en, this message translates to:
  /// **'Market cap'**
  String get marketCap;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @gainers.
  ///
  /// In en, this message translates to:
  /// **'Gainers'**
  String get gainers;

  /// No description provided for @losers.
  ///
  /// In en, this message translates to:
  /// **'Losers'**
  String get losers;

  /// No description provided for @searchOrPasteAddress.
  ///
  /// In en, this message translates to:
  /// **'Search or paste address'**
  String get searchOrPasteAddress;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @featured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featured;

  /// No description provided for @earn.
  ///
  /// In en, this message translates to:
  /// **'Earn'**
  String get earn;

  /// No description provided for @ecosystem.
  ///
  /// In en, this message translates to:
  /// **'Ecosystem'**
  String get ecosystem;

  /// No description provided for @memes.
  ///
  /// In en, this message translates to:
  /// **'Memes'**
  String get memes;

  /// No description provided for @feed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feed;

  /// No description provided for @noNewsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No news available'**
  String get noNewsAvailable;

  /// No description provided for @searchOrTypeUrl.
  ///
  /// In en, this message translates to:
  /// **'Search or type URL'**
  String get searchOrTypeUrl;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @copyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get copyUrl;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @yourWalletYourKingdom.
  ///
  /// In en, this message translates to:
  /// **'YOUR WALLET. YOUR KINGDOM.'**
  String get yourWalletYourKingdom;

  /// No description provided for @createAWallet.
  ///
  /// In en, this message translates to:
  /// **'Create a wallet'**
  String get createAWallet;

  /// No description provided for @iAlreadyHaveAWallet.
  ///
  /// In en, this message translates to:
  /// **'I already have a Wallet'**
  String get iAlreadyHaveAWallet;
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
      <String>['de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
