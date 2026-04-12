// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Solfare';

  @override
  String get portfolio => 'Portafolio';

  @override
  String get market => 'Mercado';

  @override
  String get swap => 'Intercambio';

  @override
  String get explore => 'Explorar';

  @override
  String get settings => 'Ajustes';

  @override
  String get mainWallet => 'Billetera principal';

  @override
  String get mw => 'BP';

  @override
  String get balance => 'SALDO';

  @override
  String get deposit => 'Depositar';

  @override
  String get stake => 'Staking';

  @override
  String get send => 'Enviar';

  @override
  String get tokens => 'Tokens';

  @override
  String get stocks => 'Acciones';

  @override
  String get viewAll => 'Ver todo';

  @override
  String get solana => 'Solana';

  @override
  String get customizePortfolio => 'Personalizar portafolio';

  @override
  String get noAssetsYet => 'Sin activos aún';

  @override
  String get noSolStaked => 'Sin SOL en staking';

  @override
  String get transactionHistory => 'Historial de transacciones';

  @override
  String get staking => 'Staking';

  @override
  String get activity => 'Actividad';

  @override
  String get startStaking => 'Comenzar staking';

  @override
  String get view => 'Ver';

  @override
  String get getStartedWithSol => 'Empieza con SOL';

  @override
  String get getStartedDescDevnet =>
      'Solicita SOL de prueba gratis en devnet para empezar a operar, hacer staking y explorar.';

  @override
  String get getStartedDescMainnet =>
      'Compra SOL para empezar a operar, hacer staking y explorar.';

  @override
  String get requestTestSol => 'Solicitar SOL de prueba';

  @override
  String get buySol => 'Comprar SOL';

  @override
  String get airdropRequested =>
      '¡Airdrop solicitado! El saldo se actualizará pronto.';

  @override
  String errorPrefix(Object message) {
    return 'Error: $message';
  }

  @override
  String get general => 'General';

  @override
  String get editLanguageCurrency => 'Editar idioma y moneda';

  @override
  String get addressBook => 'Libreta de direcciones';

  @override
  String get manageContacts => 'Gestionar tus contactos';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get getImportantUpdates => 'Recibir actualizaciones importantes';

  @override
  String get securityPrivacy => 'Seguridad y privacidad';

  @override
  String get manageAppsMore => 'Gestionar aplicaciones y más';

  @override
  String get support => 'Soporte';

  @override
  String get contactSupport => 'Contactar nuestro soporte';

  @override
  String version(Object version) {
    return 'Versión $version';
  }

  @override
  String get resetWallet => 'Restablecer billetera';

  @override
  String get resetWalletWarning =>
      'Esto eliminará todos los datos de la billetera. Asegúrate de haber guardado tu frase de recuperación.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get reset => 'Restablecer';

  @override
  String get language => 'Idioma';

  @override
  String get currency => 'Moneda';

  @override
  String get usDollar => 'Dólar US';

  @override
  String get network => 'Red';

  @override
  String get devnet => 'Devnet';

  @override
  String get mainnet => 'Mainnet';

  @override
  String get securityPrivacyTitle => 'Seguridad y privacidad';

  @override
  String get manageApps => 'Gestionar aplicaciones';

  @override
  String get appsConnectedPreviously => 'Aplicaciones conectadas anteriormente';

  @override
  String get spendingApprovals => 'Aprobaciones de gastos';

  @override
  String get controlSpendAssets => 'Controlar quién puede gastar tus activos';

  @override
  String get magicAi => 'Magic AI';

  @override
  String get showMagicAssistant => 'Mostrar asistente Magic en la app';

  @override
  String get biometrics => 'Biometría';

  @override
  String get unlockQuickly => 'Desbloquear rápida y seguramente';

  @override
  String get changePasscode => 'Cambiar código';

  @override
  String get updateAccountSecurity => 'Actualizar la seguridad de la cuenta';

  @override
  String get requestAuthentication => 'Solicitar autenticación';

  @override
  String get twentyFourHours => '24 horas';

  @override
  String get termsOfService => 'Términos de servicio';

  @override
  String get reviewRulesPolicies => 'Revisar reglas y políticas';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get learnDataProtection => 'Cómo usamos y protegemos tus datos';

  @override
  String get logOut => 'Cerrar sesión';

  @override
  String get removeAllWallets => 'Eliminar todas las billeteras y datos';

  @override
  String get addContact => 'Agregar contacto';

  @override
  String get name => 'Nombre';

  @override
  String get walletAddress => 'Dirección de billetera';

  @override
  String get save => 'Guardar';

  @override
  String get contacts => 'CONTACTOS';

  @override
  String get recent => 'RECIENTES';

  @override
  String get search => 'Buscar';

  @override
  String get noContactsYet => 'Sin contactos aún';

  @override
  String get yourRecoveryPhrase => 'Tu frase de recuperación';

  @override
  String get writeItDown => 'Anótala';

  @override
  String get recoveryWarning =>
      'Asegúrate de que nadie esté mirando, esta frase da acceso completo a tu billetera.';

  @override
  String get show => 'Mostrar';

  @override
  String get continueBtn => 'Continuar';

  @override
  String get skipForNow => 'Omitir por ahora';

  @override
  String get copy => 'Copiar';

  @override
  String get confirmRecoveryPhrase => 'Confirmar frase de recuperación';

  @override
  String whatIsWordNumber(Object number) {
    return '¿Cuál es la palabra $number de tu frase de recuperación?';
  }

  @override
  String get correct => '¡Correcto!';

  @override
  String get oopsTryAgain => '¡Ups, inténtalo de nuevo!';

  @override
  String justMoreWords(Object count, Object plural) {
    return 'Solo $count palabra$plural más y listo.';
  }

  @override
  String get allDoneWalletReady => '¡Listo! Tu billetera está lista.';

  @override
  String get goBackCheckPhrase =>
      'Quizás quieras verificar que anotaste correctamente la frase.';

  @override
  String get keysToYourKingdom => 'Las llaves de tu reino';

  @override
  String get keysDesc =>
      'Recibirás una frase de recuperación — un conjunto único de 12 palabras que solo tú debes conocer.';

  @override
  String get getPenPaper => 'Toma papel y lápiz';

  @override
  String get penPaperDesc =>
      'Tu frase de recuperación es más segura escrita en papel y guardada en un lugar seguro.';

  @override
  String get writeItDownTitle => 'Anótala';

  @override
  String get writeItDownDesc =>
      'Asegúrate de que nadie esté mirando — esta frase da acceso completo a tu billetera.';

  @override
  String get retry => 'Reintentar';

  @override
  String get enterRecoveryPhrase => 'Ingresa tu frase de recuperación';

  @override
  String get analyzingWallets => 'Analizando billeteras';

  @override
  String get importWallets => 'Importar billeteras';

  @override
  String get typeRecoveryPhrase => 'Escribe tu frase de recuperación';

  @override
  String get paste => 'Pegar';

  @override
  String get invalidPhraseError =>
      'Ingresa una frase de recuperación válida de 12 o 24 palabras';

  @override
  String get confirm => 'Confirmar';

  @override
  String get walletImported => 'Billetera importada';

  @override
  String get noActiveWallets => 'No se encontraron billeteras activas';

  @override
  String get quickSetup => 'Configuración rápida';

  @override
  String get advanced => 'Avanzado';

  @override
  String get enterNewPasscode => 'Nuevo código de acceso';

  @override
  String get confirmPasscode => 'Confirmar código';

  @override
  String get enterPasscode => 'Ingresar código';

  @override
  String get unlockQuicker => 'Desbloqueo rápido';

  @override
  String get unlockBiometricDesc =>
      'Desbloquea la app con tu rostro o huella, sin escribir código.';

  @override
  String get enableBiometrics => 'Activar biometría';

  @override
  String get notNow => 'Ahora no';

  @override
  String get selectRecipient => 'Seleccionar destinatario';

  @override
  String get sendTo => 'Enviar a';

  @override
  String get selectOrPasteAddress => 'Seleccionar o pegar dirección';

  @override
  String get newContact => 'Nuevo contacto';

  @override
  String get slideToApprove => 'Deslizar para aprobar';

  @override
  String get networkFee => 'Comisión de red';

  @override
  String get to => 'A';

  @override
  String get safeToCloseScreen => 'Puedes cerrar esta pantalla';

  @override
  String get sending => 'Enviando';

  @override
  String get success => 'Éxito';

  @override
  String get failed => 'Fallido';

  @override
  String get transactionIdCopied => 'ID de transacción copiado';

  @override
  String get transactionId => 'ID de transacción';

  @override
  String get explorer => 'Explorador';

  @override
  String get saveAddress => 'Guardar dirección';

  @override
  String get close => 'Cerrar';

  @override
  String get public => 'Público';

  @override
  String get noTransactionsYet => 'Sin transacciones aún';

  @override
  String get today => 'HOY';

  @override
  String get sent => 'Enviado';

  @override
  String get received => 'Recibido';

  @override
  String toAddress(Object address) {
    return 'A: $address';
  }

  @override
  String fromAddress(Object address) {
    return 'De: $address';
  }

  @override
  String get viewOnExplorer => 'Ver en explorador';

  @override
  String get copyTransactionId => 'Copiar ID de transacción';

  @override
  String get share => 'Compartir';

  @override
  String get date => 'FECHA';

  @override
  String get details => 'DETALLES';

  @override
  String get transactionResult => 'RESULTADO DE TRANSACCIÓN';

  @override
  String get networkFeeLabel => 'COMISIÓN DE RED';

  @override
  String get transactionIdLabel => 'ID DE TRANSACCIÓN';

  @override
  String get linkCopied => 'Enlace copiado — abrir en navegador';

  @override
  String get youreAllSet => '¡Todo listo!';

  @override
  String get walletSecuredDesc =>
      'Tu billetera está asegurada y solo tú tienes las llaves. ¡Empieza a explorar tu reino!';

  @override
  String get trending => 'Tendencias';

  @override
  String get marketCap => 'Cap. mercado';

  @override
  String get volume => 'Volumen';

  @override
  String get gainers => 'Ganadores';

  @override
  String get losers => 'Perdedores';

  @override
  String get searchOrPasteAddress => 'Buscar o pegar dirección';

  @override
  String get discover => 'Descubrir';

  @override
  String get featured => 'Destacado';

  @override
  String get earn => 'Ganar';

  @override
  String get ecosystem => 'Ecosistema';

  @override
  String get memes => 'Memes';

  @override
  String get feed => 'Noticias';

  @override
  String get noNewsAvailable => 'Sin noticias disponibles';

  @override
  String get searchOrTypeUrl => 'Buscar o escribir URL';

  @override
  String get reload => 'Recargar';

  @override
  String get copyUrl => 'Copiar URL';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get yourWalletYourKingdom => 'TU BILLETERA. TU REINO.';

  @override
  String get createAWallet => 'Crear una billetera';

  @override
  String get iAlreadyHaveAWallet => 'Ya tengo una billetera';
}
