import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/features/explore/presentation/bloc/explore_bloc.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_bloc.dart';
import 'package:solfare/features/market/presentation/bloc/market_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/passcode_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      // Provide BLoCs to the entire app
      // These can be accessed from any widget using BlocProvider.of(context)
      providers: [
        // Wallet BLoC - for wallet creation and management
        BlocProvider(
          create: (context) => WalletBloc(),
        ),
        // Passcode BLoC - for passcode entry and verification
        BlocProvider(
          create: (context) => PasscodeBloc(),
        ),
        // Homepage BLoC - for navigation state
        BlocProvider(
          create: (context) => HomepageBloc(),
        ),
        // Market BLoC - for market data
        BlocProvider(
          create: (context) => MarketBloc(),
        ),
        // Explore BLoC - for explore/dApp browser
        BlocProvider(
          create: (context) => ExploreBloc(),
        ),
      ],
      child: MaterialApp.router(
        //showPerformanceOverlay: true,
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
      ),
    );
  }
}
