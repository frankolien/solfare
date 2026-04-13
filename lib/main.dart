import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/core/locale/locale_provider.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/features/explore/presentation/bloc/explore_bloc.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_bloc.dart';
import 'package:solfare/features/market/presentation/bloc/market_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NetworkConstants.load();
  runApp(const MainApp());
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
