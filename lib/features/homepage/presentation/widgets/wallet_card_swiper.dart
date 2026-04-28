import 'dart:async';

import 'package:flutter/material.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';

/// Horizontal swipeable carousel of wallet cards. The last page is always
/// a dashed-outline "add wallet" placeholder.
///
/// Design goals:
///   - Swiping between real wallets eventually fires [onWalletSelected] with
///     the landed-on wallet's id. A debounce stops fast drag sequences from
///     flooding the bloc with SwitchWalletEvents.
///   - Overshooting to the trailing [_AddWalletPage] opens a sheet but does
///     NOT switch the active wallet — if the user taps the card, [onAddWallet]
///     fires. We also snap back to the previously active page so they don't
///     end on the empty placeholder after tapping cancel.
class WalletCardSwiper extends StatefulWidget {
  final List<WalletAccount> wallets;
  final String? activeWalletId;

  /// Child builder called for each wallet — pass the wallet so the consumer
  /// can render the real BalanceCard. We keep the swiper unaware of balances
  /// so the homepage stays in charge of all data wiring.
  final Widget Function(BuildContext context, WalletAccount wallet)
      walletBuilder;

  final ValueChanged<String>? onWalletSelected;
  final VoidCallback? onAddWallet;

  const WalletCardSwiper({
    super.key,
    required this.wallets,
    required this.activeWalletId,
    required this.walletBuilder,
    this.onWalletSelected,
    this.onAddWallet,
  });

  @override
  State<WalletCardSwiper> createState() => _WalletCardSwiperState();
}

class _WalletCardSwiperState extends State<WalletCardSwiper> {
  late PageController _controller;
  late int _currentPage;
  Timer? _switchDebounce;

  @override
  void initState() {
    super.initState();
    _currentPage = _indexOfActive();
    _controller = PageController(initialPage: _currentPage);
  }

  @override
  void didUpdateWidget(covariant WalletCardSwiper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the active wallet changes externally (new wallet added,
    // switched from settings, etc.) keep the page in sync without firing
    // another SwitchWalletEvent ourselves.
    final target = _indexOfActive();
    if (target != _currentPage && _controller.hasClients) {
      _currentPage = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients) return;
        _controller.animateToPage(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _switchDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  int _indexOfActive() {
    if (widget.activeWalletId == null || widget.wallets.isEmpty) return 0;
    final i = widget.wallets.indexWhere((w) => w.id == widget.activeWalletId);
    return i < 0 ? 0 : i;
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    _switchDebounce?.cancel();
    _switchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      // Last page is the add-wallet slot — don't try to switch.
      if (page >= widget.wallets.length) return;
      final selected = widget.wallets[page];
      if (selected.id != widget.activeWalletId) {
        widget.onWalletSelected?.call(selected.id);
      }
    });
  }

  void _handleAddTap() {
    widget.onAddWallet?.call();
    // Snap back to the previously active wallet so the user doesn't end on
    // the empty slot if they dismiss the sheet.
    final returnTo = _indexOfActive();
    if (_controller.hasClients) {
      _controller.animateToPage(
        returnTo,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.wallets.length + 1;
    return Column(
      children: [
        SizedBox(
          // Fixed viewport for the PageView. Needs to comfortably fit the
          // BalanceCard's content at all text scales without overflowing.
          height: 240,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: _onPageChanged,
            itemCount: totalPages,
            itemBuilder: (context, i) {
              if (i == widget.wallets.length) {
                return _AddWalletPage(onTap: _handleAddTap);
              }
              return widget.walletBuilder(context, widget.wallets[i]);
            },
          ),
        ),
        const SizedBox(height: 6),
        _PageDots(count: totalPages, current: _currentPage),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  const _PageDots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _AddWalletPage extends StatelessWidget {
  final VoidCallback onTap;
  const _AddWalletPage({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        constraints: const BoxConstraints(minHeight: 190),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: Colors.white24,
            radius: 16,
            dashLength: 6,
            gapLength: 5,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  child: const Icon(Icons.add, color: Colors.white70, size: 22),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add wallet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create or import another wallet',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontFamily: 'FKGrotesk',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hand-rolled dashed rounded rectangle — saves pulling in a new dependency
/// for a one-off border style.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashLength;
  final double gapLength;

  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashLength,
    required this.gapLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dashLength != dashLength ||
      old.gapLength != gapLength;
}
