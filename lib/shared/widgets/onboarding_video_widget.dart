/*

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class OnboardingVideoWidget extends StatefulWidget {
  const OnboardingVideoWidget({super.key});

  @override
  State<OnboardingVideoWidget> createState() => _OnboardingVideoWidgetState();
}

class _OnboardingVideoWidgetState extends State<OnboardingVideoWidget> {
  late VideoPlayerController _controller;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/assets/videos/onboarding/welcome_screen_video.mp4');
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return VideoPlayer(_controller);
  }
}*/

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SpinningVideoCard extends StatefulWidget {
  const SpinningVideoCard({super.key});

  @override
  State<SpinningVideoCard> createState() => _SpinningVideoCardState();
}

class _SpinningVideoCardState extends State<SpinningVideoCard> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset('assets/assets/videos/onboarding/welcome_screen_video.mp4')
      ..setLooping(true)
      ..setVolume(0.0) // silent
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: const Color(0xFFFFF257),
        child: _controller.value.isInitialized
            ? FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}