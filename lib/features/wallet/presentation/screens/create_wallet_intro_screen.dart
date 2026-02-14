import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:video_player/video_player.dart';

/// Data for each intro step shown before the recovery phrase.
class _IntroStep {
  final String videoAsset;
  final String title;
  final String description;

  const _IntroStep({
    required this.videoAsset,
    required this.title,
    required this.description,
  });
}

const _steps = [
  _IntroStep(
    videoAsset: 'assets/assets/videos/onboarding/create_wallet_step_1.mp4',
    title: 'Keys to Your Kingdom',
    description:
        'You\'ll get a recovery phrase—a unique set of 12 words that only you should know.',
  ),
  _IntroStep(
    videoAsset: 'assets/assets/videos/onboarding/create_wallet_step_2.mp4',
    title: 'Get Pen & Paper',
    description:
        'Your recovery phrase is safest when written on paper and stored in a secure place.',
  ),
  _IntroStep(
    videoAsset: 'assets/assets/videos/onboarding/create_wallet_step_3.mp4',
    title: 'Write it Down',
    description:
        'Make sure no one is watching—this phrase gives full access to your wallet. Never share it with anyone.',
  ),
];

class CreateWalletIntroScreen extends StatefulWidget {
  const CreateWalletIntroScreen({super.key});

  @override
  State<CreateWalletIntroScreen> createState() =>
      _CreateWalletIntroScreenState();
}

class _CreateWalletIntroScreenState extends State<CreateWalletIntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  /// One video controller per step, initialized lazily.
  final List<VideoPlayerController?> _videoControllers =
      List.filled(_steps.length, null);

  @override
  void initState() {
    super.initState();
    _initVideo(0);
  }

  Future<void> _initVideo(int index) async {
    if (_videoControllers[index] != null) return;

    final controller =
        VideoPlayerController.asset(_steps[index].videoAsset)
          ..setLooping(true)
          ..setVolume(0);

    _videoControllers[index] = controller;
    await controller.initialize();
    if (mounted) {
      setState(() {});
      controller.play();
    }
  }

  void _onPageChanged(int page) {
    // Pause the old video
    _videoControllers[_currentPage]?.pause();

    setState(() => _currentPage = page);

    // Init & play the new video
    _initVideo(page).then((_) {
      _videoControllers[page]?.seekTo(Duration.zero);
      _videoControllers[page]?.play();
    });
  }

  void _onContinue() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // All 3 steps done → go to recovery phrase screen
      context.push(AppRoutes.recoveryPhrase);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _videoControllers) {
      controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Progress bars at top
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(_steps.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: index < _currentPage
                              ? 1.0
                              : index == _currentPage
                                  ? 1.0
                                  : 0.0,
                          minHeight: 3,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            index <= _currentPage
                                ? Colors.white
                                : Colors.white12,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Close button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 26),
                onPressed: () => context.pop(),
              ),
            ),

            // Video + text page view (tap anywhere to advance)
            Expanded(
              child: GestureDetector(
                onTap: _onContinue,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    return _buildStep(index);
                  },
                ),
              ),
            ),

            // Continue button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _onContinue,
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int index) {
    final step = _steps[index];
    final controller = _videoControllers[index];
    final isInitialized = controller?.value.isInitialized ?? false;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // Video card — fixed proportion of screen
          Container(
            width: double.infinity,
            height: screenHeight * 0.5,
            //color: const Color(0xFF0B0F14),
            child: isInitialized
                ? ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      1.3, 0, 0, 0, -38,
                      0, 1.3, 0, 0, -38,
                      0, 0, 1.3, 0, -38,
                      0, 0, 0, 1, 0,
                    ]),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller!.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    ),
                  )
                : const Center(
                    child:
                        CircularProgressIndicator(color: Colors.yellow),
                  ),
          ),

          const Spacer(flex: 2),

          // Title
          Text(
            step.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            step.description,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
