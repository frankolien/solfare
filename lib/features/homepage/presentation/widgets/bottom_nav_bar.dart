import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:solfare/l10n/app_localizations.dart';

const _lottiePaths = [
  'assets/assets/lottie/portfolio_icon.json',
  'assets/assets/lottie/market_icon.json',
  'assets/assets/lottie/trade_icon.json',
  'assets/assets/lottie/browser_icon.json',
  'assets/assets/lottie/settings_icon.json',
];

List<String> _navLabels(BuildContext context) {
  final l = AppLocalizations.of(context)!;
  return [l.portfolio, l.market, l.swap, l.explore, l.settings];
}

class BottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.selectedIndex;
    _controllers = List.generate(
      _lottiePaths.length,
      (index) => AnimationController(vsync: this),
    );
  }

  @override
  void didUpdateWidget(BottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);              
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _controllers[_previousIndex].reset();
      _controllers[widget.selectedIndex].forward(from: 0);
      _previousIndex = widget.selectedIndex;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Nav bar background
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0E1014),
            border: Border(
              top: BorderSide(color: Colors.white10, width: 1),
            ),
          ),
          padding: EdgeInsets.only(top: 14, bottom: bottomPadding > 0 ? bottomPadding : 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_lottiePaths.length, (index) {
              final labels = _navLabels(context);
              final isSelected = index == widget.selectedIndex;

              return GestureDetector(
                onTap: () => widget.onTap(index),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lottie icon
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: Lottie.asset(
                        _lottiePaths[index],
                        controller: _controllers[index],
                        onLoaded: (composition) {
                          _controllers[index].duration = composition.duration;
                          if (index == widget.selectedIndex) {
                            _controllers[index].forward();
                          }
                        },
                        delegates: LottieDelegates(
                          values: [
                            ValueDelegate.colorFilter(
                              const ['**'],
                              value: ColorFilter.mode(
                                isSelected ? Colors.white : Colors.grey[600]!,
                                BlendMode.srcIn,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Label
                    Text(
                      labels[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[600],
                        fontSize: 10,
                        fontFamily: 'FKGrotesk',
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        // Yellow indicator — positioned on the top border line
        Positioned(
          top: -2,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_lottiePaths.length, (index) {
              final isSelected = index == widget.selectedIndex;

              return Container(
                height: 4,
                width: 56,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.yellow : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
