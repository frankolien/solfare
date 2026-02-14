import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:video_player/video_player.dart';

class SetupCompleteScreen extends StatefulWidget {
  const SetupCompleteScreen({super.key});

  @override
  State<SetupCompleteScreen> createState() => _SetupCompleteScreenState();
}

class _SetupCompleteScreenState extends State<SetupCompleteScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.asset(
        'assets/assets/videos/onboarding/onboarding_success.mp4',
      )
        ..setLooping(true)
        ..setVolume(0);

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller!.play();
      }
    } catch (e) {
      // If video fails to load, just show the static UI
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Flag video at top
              Container(
                width: double.infinity,
                height: screenHeight * 0.4,
                alignment: Alignment.topRight,
                child: _isInitialized && _controller != null
                    ? ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          1.3, 0, 0, 0, -38,
                          0, 1.3, 0, 0, -38,
                          0, 0, 1.3, 0, -38,
                          0, 0, 0, 1, 0,
                        ]),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          alignment: Alignment.topRight,
                          child: SizedBox(
                            width: _controller!.value.size.width,
                            height: _controller!.value.size.height,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[900]?.withOpacity(0.3),
                        child: const Icon(
                          Icons.flag,
                          color: Colors.white,
                          size: 80,
                        ),
                      ),
              ),

              const Spacer(flex: 2),

              // Title
              const Text(
                'You\'re All Set',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                'Your wallet is secured, and only you hold the keys. Start exploring your kingdom!',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // Explore button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => context.go(AppRoutes.homepage),
                  child: const Text(
                    'Explore',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
