import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/core/security/app_lock.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _svgFadeOut;
  late final Animation<Offset> _lottieSlideIn;

  // Storage answered with an error rather than an answer. Held here so the
  // screen can stay put and offer a retry instead of navigating onward.
  bool _unreadable = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // SVG fades out from fully visible to invisible
    _svgFadeOut = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Lottie slides from right (1,0) to center (0,0)
    _lottieSlideIn = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _controller.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        context.read<WalletBloc>().add(const CheckWalletExistsEvent());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WalletBloc, WalletState>(
      // Listen to wallet state changes for navigation
      listener: (context, state) async {
        if (state is WalletExistsChecked) {
          // iOS Keychain persists across uninstalls, so a wallet can exist
          // without its paired passcode (e.g. manual Keychain reset, old
          // install). In that case sending the user to unlock traps them —
          // bounce to onboarding instead.
          if (state.exists) {
            // AppLock already read this before the first frame, and owns it
            // from here on — it is the same fact the router's redirect gates
            // on, so asking storage again could only disagree with it.
            if (AppLock.instance.hasPasscode) {
              context.go(AppRoutes.unlockPasscode);
            } else {
              context.go(AppRoutes.onboarding);
            }
          } else {
            context.go(AppRoutes.onboarding);
          }
        } else if (state is WalletStoreUnreadable || state is WalletError) {
          // Emphatically not onboarding. Storage said something went wrong,
          // not that the device is empty, and onboarding's first act is to
          // write a new wallet over whatever is there. Stop and say so.
          setState(() => _unreadable = true);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _unreadable ? _storeUnreadable() : _logo(),
        ),
      ),
    );
  }

  Widget _logo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        FadeTransition(
          opacity: _svgFadeOut,
          child: SvgPicture.asset(
            'assets/assets/images/solflare_logo.svg',
            width: 100,
            height: 100,
            colorFilter: const ColorFilter.mode(Colors.yellow, BlendMode.srcIn),
          ),
        ),
        SlideTransition(
          position: _lottieSlideIn,
          child: Lottie.asset(
            'assets/assets/lottie/splash_logo.json',
            width: 300,
            height: 300,
            repeat: false,
          ),
        ),
      ],
    );
  }

  /// Offers a retry and nothing else. Every other affordance here — create a
  /// wallet, import a wallet — writes to the store we just failed to read.
  Widget _storeUnreadable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: Colors.grey[600], size: 28),
          const SizedBox(height: 16),
          const Text(
            'Could not open your wallet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This device could not read its secure storage. Your wallet has '
            'not been changed. Try again, and if it keeps failing, restart '
            'the phone before setting up a new wallet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              fontFamily: 'FKGrotesk',
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () {
              setState(() => _unreadable = false);
              context.read<WalletBloc>().add(const CheckWalletExistsEvent());
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.yellow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Try again',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
