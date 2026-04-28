import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/locale/locale_provider.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/features/explore/presentation/bloc/explore_bloc.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_bloc.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_bloc.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_bloc.dart';
import 'package:solfare/features/market/presentation/bloc/market_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await NetworkConstants.load();
  await _wipeSecureStorageOnFreshInstall();
  runApp(const MainApp());
}

/// iOS keeps Keychain entries across app uninstalls, so a fresh reinstall
/// inherits whatever mnemonic/passcode/etc the previous install left behind
/// — which causes "ghost wallets", orphaned passcodes, and stuck unlock
/// screens. SharedPreferences *is* wiped on uninstall, so we use its
/// absence as the signal for "truly fresh install" and nuke everything in
/// secure storage once, at the very top of the boot.
Future<void> _wipeSecureStorageOnFreshInstall() async {
  const flag = 'app_installed_v1';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(flag) == true) return;
  try {
    await const FlutterSecureStorage().deleteAll();
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

  @override
  void initState() {
    super.initState();
    _localeProvider.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
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
        BlocProvider(create: (context) => MarketBloc()),
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
        ),
      ),
    );
  }
}

/// InheritedWidget so any screen can access the LocaleProvider
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

