import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

    // Dispatch event to check if wallet exists
    // BLoC will handle the check and emit state
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
      listener: (context, state) {
        if (state is WalletExistsChecked) {
          // Navigate based on wallet existence
          if (state.exists) {
            context.go(AppRoutes.unlockPasscode);
          } else {
            context.go(AppRoutes.onboarding);
          }
        } else if (state is WalletError) {
          // If check fails, default to onboarding
          context.go(AppRoutes.onboarding);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              FadeTransition(
                opacity: _svgFadeOut,
                child: SvgPicture.asset(
                  'assets/assets/images/solflare_logo.svg',
                  width: 100,
                  height: 100,
                  color: Colors.yellow,
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
          ),
        ),
      ),
    );
  }
}
