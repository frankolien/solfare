// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Solfare';

  @override
  String get portfolio => 'Portefeuille';

  @override
  String get market => 'Marché';

  @override
  String get swap => 'Échange';

  @override
  String get explore => 'Explorer';

  @override
  String get settings => 'Paramètres';

  @override
  String get mainWallet => 'Portefeuille principal';

  @override
  String get mw => 'PP';

  @override
  String get balance => 'SOLDE';

  @override
  String get deposit => 'Dépôt';

  @override
  String get stake => 'Staking';

  @override
  String get send => 'Envoyer';

  @override
  String get tokens => 'Jetons';

  @override
  String get stocks => 'Actions';

  @override
  String get viewAll => 'Tout voir';

  @override
  String get solana => 'Solana';

  @override
  String get customizePortfolio => 'Personnaliser le portefeuille';

  @override
  String get noAssetsYet => 'Aucun actif pour le moment';

  @override
  String get noSolStaked => 'Aucun SOL staké';

  @override
  String get transactionHistory => 'Historique des transactions';

  @override
  String get staking => 'Staking';

  @override
  String get activity => 'Activité';

  @override
  String get startStaking => 'Commencer le staking';

  @override
  String get view => 'Voir';

  @override
  String get getStartedWithSol => 'Commencez avec SOL';

  @override
  String get getStartedDescDevnet =>
      'Demandez des SOL de test gratuits sur devnet pour commencer à trader, staker et explorer. Vous aurez besoin d\'un petit montant de SOL pour chaque transaction Solana.';

  @override
  String get getStartedDescMainnet =>
      'Achetez des SOL pour commencer à trader, staker et explorer. Vous aurez besoin d\'un petit montant de SOL pour chaque transaction Solana.';

  @override
  String get requestTestSol => 'Demander des SOL de test';

  @override
  String get buySol => 'Acheter des SOL';

  @override
  String get airdropRequested =>
      'Airdrop demandé ! Le solde sera mis à jour bientôt.';

  @override
  String errorPrefix(Object message) {
    return 'Erreur : $message';
  }

  @override
  String get general => 'Général';

  @override
  String get editLanguageCurrency => 'Modifier la langue et la devise';

  @override
  String get addressBook => 'Carnet d\'adresses';

  @override
  String get manageContacts => 'Gérer vos contacts';

  @override
  String get notifications => 'Notifications';

  @override
  String get getImportantUpdates => 'Recevoir les mises à jour importantes';

  @override
  String get securityPrivacy => 'Sécurité et confidentialité';

  @override
  String get manageAppsMore => 'Gérer les applications et plus';

  @override
  String get support => 'Support';

  @override
  String get contactSupport => 'Contacter notre support client';

  @override
  String version(Object version) {
    return 'Version $version';
  }

  @override
  String get resetWallet => 'Réinitialiser le portefeuille';

  @override
  String get resetWalletWarning =>
      'Cela supprimera toutes les données du portefeuille de cet appareil. Assurez-vous d\'avoir sauvegardé votre phrase de récupération.';

  @override
  String get cancel => 'Annuler';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get language => 'Langue';

  @override
  String get currency => 'Devise';

  @override
  String get usDollar => 'Dollar US';

  @override
  String get network => 'Réseau';

  @override
  String get devnet => 'Devnet';

  @override
  String get mainnet => 'Mainnet';

  @override
  String get securityPrivacyTitle => 'Sécurité et confidentialité';

  @override
  String get manageApps => 'Gérer les applications';

  @override
  String get appsConnectedPreviously => 'Applications connectées précédemment';

  @override
  String get spendingApprovals => 'Approbations de dépenses';

  @override
  String get controlSpendAssets => 'Contrôler qui peut dépenser vos actifs';

  @override
  String get magicAi => 'Magic AI';

  @override
  String get showMagicAssistant => 'Afficher l\'assistant Magic dans l\'app';

  @override
  String get biometrics => 'Biométrie';

  @override
  String get unlockQuickly => 'Déverrouillez rapidement et en toute sécurité';

  @override
  String get changePasscode => 'Changer le code';

  @override
  String get updateAccountSecurity => 'Mettre à jour la sécurité du compte';

  @override
  String get requestAuthentication => 'Demander l\'authentification';

  @override
  String get twentyFourHours => '24 heures';

  @override
  String get termsOfService => 'Conditions d\'utilisation';

  @override
  String get reviewRulesPolicies => 'Consulter les règles et politiques';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get learnDataProtection =>
      'Découvrir comment nous utilisons et protégeons vos données';

  @override
  String get logOut => 'Déconnexion';

  @override
  String get removeAllWallets =>
      'Supprimer tous les portefeuilles et effacer les données';

  @override
  String get addContact => 'Ajouter un contact';

  @override
  String get name => 'Nom';

  @override
  String get walletAddress => 'Adresse du portefeuille';

  @override
  String get save => 'Enregistrer';

  @override
  String get contacts => 'CONTACTS';

  @override
  String get recent => 'RÉCENTS';

  @override
  String get search => 'Rechercher';

  @override
  String get noContactsYet => 'Aucun contact';

  @override
  String get yourRecoveryPhrase => 'Votre phrase de récupération';

  @override
  String get writeItDown => 'Notez-la';

  @override
  String get recoveryWarning =>
      'Assurez-vous que personne ne regarde, cette phrase donne un accès complet à votre portefeuille. Ne la partagez jamais.';

  @override
  String get show => 'Afficher';

  @override
  String get continueBtn => 'Continuer';

  @override
  String get skipForNow => 'Passer pour l\'instant';

  @override
  String get copy => 'Copier';

  @override
  String get confirmRecoveryPhrase => 'Confirmer la phrase de récupération';

  @override
  String whatIsWordNumber(Object number) {
    return 'Quel est le ${number}e mot de votre phrase de récupération ?';
  }

  @override
  String get correct => 'Correct !';

  @override
  String get oopsTryAgain => 'Oups, réessayez !';

  @override
  String justMoreWords(Object count, Object plural) {
    return 'Encore $count mot$plural et c\'est terminé.';
  }

  @override
  String get allDoneWalletReady => 'Terminé ! Votre portefeuille est prêt.';

  @override
  String get goBackCheckPhrase =>
      'Vous devriez peut-être vérifier que vous avez bien noté la phrase de récupération.';

  @override
  String get keysToYourKingdom => 'Les clés de votre royaume';

  @override
  String get keysDesc =>
      'Vous recevrez une phrase de récupération — un ensemble unique de 12 mots que vous seul devez connaître.';

  @override
  String get getPenPaper => 'Prenez un stylo et du papier';

  @override
  String get penPaperDesc =>
      'Votre phrase de récupération est plus sûre écrite sur papier et stockée en lieu sûr.';

  @override
  String get writeItDownTitle => 'Notez-la';

  @override
  String get writeItDownDesc =>
      'Assurez-vous que personne ne regarde — cette phrase donne un accès complet à votre portefeuille. Ne la partagez jamais.';

  @override
  String get retry => 'Réessayer';

  @override
  String get enterRecoveryPhrase => 'Entrez votre phrase de récupération';

  @override
  String get analyzingWallets => 'Analyse des portefeuilles';

  @override
  String get importWallets => 'Importer les portefeuilles';

  @override
  String get typeRecoveryPhrase => 'Tapez votre phrase de récupération';

  @override
  String get paste => 'Coller';

  @override
  String get invalidPhraseError =>
      'Veuillez entrer une phrase de récupération valide de 12 ou 24 mots';

  @override
  String get confirm => 'Confirmer';

  @override
  String get walletImported => 'Portefeuille importé';

  @override
  String get noActiveWallets => 'Aucun portefeuille actif trouvé';

  @override
  String get quickSetup => 'Configuration rapide';

  @override
  String get advanced => 'Avancé';

  @override
  String get enterNewPasscode => 'Nouveau code d\'accès';

  @override
  String get confirmPasscode => 'Confirmer le code';

  @override
  String get enterPasscode => 'Entrer le code';

  @override
  String get unlockQuicker => 'Déverrouillage rapide';

  @override
  String get unlockBiometricDesc =>
      'Déverrouillez l\'app avec votre visage ou empreinte, sans taper de code.';

  @override
  String get enableBiometrics => 'Activer la biométrie';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get selectRecipient => 'Sélectionner le destinataire';

  @override
  String get sendTo => 'Envoyer à';

  @override
  String get selectOrPasteAddress => 'Sélectionner ou coller une adresse';

  @override
  String get newContact => 'Nouveau contact';

  @override
  String get slideToApprove => 'Glisser pour approuver';

  @override
  String get networkFee => 'Frais de réseau';

  @override
  String get to => 'À';

  @override
  String get safeToCloseScreen =>
      'Vous pouvez fermer cet écran en toute sécurité';

  @override
  String get sending => 'Envoi en cours';

  @override
  String get success => 'Succès';

  @override
  String get failed => 'Échec';

  @override
  String get transactionIdCopied => 'ID de transaction copié';

  @override
  String get transactionId => 'ID de transaction';

  @override
  String get explorer => 'Explorateur';

  @override
  String get saveAddress => 'Enregistrer l\'adresse';

  @override
  String get close => 'Fermer';

  @override
  String get public => 'Public';

  @override
  String get noTransactionsYet => 'Aucune transaction';

  @override
  String get today => 'AUJOURD\'HUI';

  @override
  String get sent => 'Envoyé';

  @override
  String get received => 'Reçu';

  @override
  String toAddress(Object address) {
    return 'À : $address';
  }

  @override
  String fromAddress(Object address) {
    return 'De : $address';
  }

  @override
  String get viewOnExplorer => 'Voir sur l\'explorateur';

  @override
  String get copyTransactionId => 'Copier l\'ID de transaction';

  @override
  String get share => 'Partager';

  @override
  String get date => 'DATE';

  @override
  String get details => 'DÉTAILS';

  @override
  String get transactionResult => 'RÉSULTAT DE LA TRANSACTION';

  @override
  String get networkFeeLabel => 'FRAIS DE RÉSEAU';

  @override
  String get transactionIdLabel => 'ID DE TRANSACTION';

  @override
  String get linkCopied => 'Lien copié — ouvrir dans le navigateur';

  @override
  String get youreAllSet => 'Vous êtes prêt !';

  @override
  String get walletSecuredDesc =>
      'Votre portefeuille est sécurisé et vous seul détenez les clés. Commencez à explorer votre royaume !';

  @override
  String get trending => 'Tendances';

  @override
  String get marketCap => 'Cap. marché';

  @override
  String get volume => 'Volume';

  @override
  String get gainers => 'Hausse';

  @override
  String get losers => 'Baisse';

  @override
  String get searchOrPasteAddress => 'Rechercher ou coller une adresse';

  @override
  String get discover => 'Découvrir';

  @override
  String get featured => 'En vedette';

  @override
  String get earn => 'Gagner';

  @override
  String get ecosystem => 'Écosystème';

  @override
  String get memes => 'Mèmes';

  @override
  String get feed => 'Fil';

  @override
  String get noNewsAvailable => 'Aucune actualité disponible';

  @override
  String get searchOrTypeUrl => 'Rechercher ou saisir une URL';

  @override
  String get reload => 'Recharger';

  @override
  String get copyUrl => 'Copier l\'URL';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get yourWalletYourKingdom => 'VOTRE PORTEFEUILLE. VOTRE ROYAUME.';

  @override
  String get createAWallet => 'Créer un portefeuille';

  @override
  String get iAlreadyHaveAWallet => 'J\'ai déjà un portefeuille';
}
