import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/features/homepage/presentation/screens/homepage_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/biometric_setup_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/create_wallet_intro_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/confirm_recovery_phrase_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/create_wallet_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/passcode_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/setup_complete_screen.dart';
import 'package:solfare/features/wallet/domain/entities/wallet.dart';
import 'package:solfare/shared/screens/onboarding/onboarding_screen.dart';
import 'package:solfare/shared/screens/splash/splash_screen.dart';

/// Centralized route path constants.
/// Every route in the app is defined here — one source of truth.
abstract class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String createWallet = '/create-wallet';
  static const String recoveryPhrase = '/recovery-phrase';
  static const String confirmRecoveryPhrase = '/confirm-recovery-phrase';
  static const String enterPasscode = '/enter-passcode';
  static const String confirmPasscode = '/confirm-passcode';
  static const String unlockPasscode = '/unlock-passcode';
  static const String biometricSetup = '/biometric-setup';
  static const String setupComplete = '/setup-complete';
  static const String homepage = '/homepage';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: FadeTransition(
              opacity: curvedAnimation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    ),
    GoRoute(
      path: AppRoutes.createWallet,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const CreateWalletIntroScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    ),
    GoRoute(
      path: AppRoutes.recoveryPhrase,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const CreateWalletScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    ),
    GoRoute(
      path: AppRoutes.confirmRecoveryPhrase,
      pageBuilder: (context, state) {
        final wallet = state.extra as Wallet;
        return CustomTransitionPage(
          key: state.pageKey,
          child: ConfirmRecoveryPhraseScreen(wallet: wallet),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.enterPasscode,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const PasscodeScreen(mode: PasscodeMode.enter),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    ),
    GoRoute(
      path: AppRoutes.unlockPasscode,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const PasscodeScreen(mode: PasscodeMode.unlock),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return FadeTransition(
            opacity: curvedAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
    GoRoute(
      path: AppRoutes.confirmPasscode,
      pageBuilder: (context, state) {
        final passcode = state.extra as String;
        return CustomTransitionPage(
          key: state.pageKey,
          child: PasscodeScreen(
            mode: PasscodeMode.confirm,
            initialPasscode: passcode,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.biometricSetup,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const BiometricSetupScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    ),
    GoRoute(
      path: AppRoutes.setupComplete,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SetupCompleteScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    ),
    GoRoute(
      path: AppRoutes.homepage,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const HomepageScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );
          return FadeTransition(
            opacity: curvedAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ),
  ],
);
