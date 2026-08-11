import 'package:flutter/material.dart';

/// Sweeps a highlight across whatever it wraps, to say "loading" without
/// saying a number.
///
/// One controller drives every box beneath it, so a skeleton screen animates
/// in step and costs one ticker rather than one per placeholder.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          // Travels from fully off one edge to fully off the other, so the
          // highlight never sits parked at the start or the end.
          final slide = _controller.value * 2 - 1;
          return LinearGradient(
            begin: Alignment(slide - 0.6, -0.2),
            end: Alignment(slide + 0.6, 0.2),
            colors: const [
              Color(0xFF23262E),
              Color(0xFF32363F),
              Color(0xFF23262E),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// One placeholder block. Only its shape matters — [Shimmer] paints it.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF23262E),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
