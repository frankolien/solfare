import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfare/core/constant/api_keys.dart';
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/deeplink/deep_link_bridge.dart';
import 'package:solfare/core/locale/locale_provider.dart';
import 'package:solfare/core/security/app_lock.dart';
import 'package:solfare/core/security/secure_store.dart';
import 'package:solfare/features/wallet/presentation/widgets/dapp_request_host.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/features/explore/presentation/bloc/explore_bloc.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_bloc.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_bloc.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_bloc.dart';
import 'package:solfare/features/market/presentation/bloc/market_home_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiKeys.loadLocalEnv();
  await NetworkConstants.load();
  await _wipeSecureStorageOnFreshInstall();
  // Before the first frame, so the router's first redirect already knows
  // whether a passcode is expected rather than letting one frame of wallet
  // through while it finds out.
  await AppLock.instance.load();
  DeepLinkBridge.init(appRouter);
  runApp(const MainApp());
}

// iOS keeps Keychain entries across app uninstalls, so a fresh reinstall
// inherits whatever mnemonic/passcode/etc the previous install left behind
// — which causes "ghost wallets", orphaned passcodes, and stuck unlock
// screens. SharedPreferences *is* wiped on uninstall, so we use its
// absence as the signal for "truly fresh install" and nuke everything in
// secure storage once, at the very top of the boot.
Future<void> _wipeSecureStorageOnFreshInstall() async {
  const flag = 'app_installed_v1';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(flag) == true) return;
  try {
    await SecureStore.instance.deleteAll();
  } catch (_) {
    // Best-effort — never block app startup if Keychain access hiccups.
  }
  await prefs.setBool(flag, true);
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _localeProvider = LocaleProvider();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _localeProvider.addListener(() {
      setState(() {});
    });
    // The passcode was only ever asked for at cold start, so a phone left
    // unlocked and handed over hours later opened straight onto the wallet.
    // Locking is decided on return rather than on leaving, so the app does
    // not tear down what the user was doing while they are not looking.
    _lifecycle = AppLifecycleListener(
      onPause: AppLock.instance.didLeave,
      onRestart: AppLock.instance.didReturn,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _localeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => WalletBloc()),
        BlocProvider(create: (context) => PasscodeBloc()),
        BlocProvider(create: (context) => HomepageBloc()),
        BlocProvider(create: (context) => MarketHomeBloc()),
        BlocProvider(create: (context) => ExploreBloc()),
        BlocProvider(create: (context) => SwapBloc()),
        BlocProvider(create: (context) => StakingBloc()),
      ],
      child: _LocaleScope(
        provider: _localeProvider,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: appRouter,
          locale: _localeProvider.locale,
          supportedLocales: LocaleProvider.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Wraps every route: a dapp request arrives whenever another app
          // opens us, and must not depend on which screen was showing.
          builder: (context, child) =>
              DappRequestHost(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

// InheritedWidget so any screen can access the LocaleProvider
class _LocaleScope extends InheritedWidget {
  final LocaleProvider provider;

  const _LocaleScope({required this.provider, required super.child});

  static LocaleProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_LocaleScope>()!.provider;
  }

  @override
  bool updateShouldNotify(_LocaleScope oldWidget) => provider.locale != oldWidget.provider.locale;
}

/// Extension for easy access from any widget
extension LocaleProviderExtension on BuildContext {
  LocaleProvider get localeProvider => _LocaleScope.of(this);
}

