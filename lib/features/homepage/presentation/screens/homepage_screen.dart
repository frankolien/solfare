import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_bloc.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_event.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_state.dart';

class HomepageScreen extends StatelessWidget {
  const HomepageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // BlocBuilder listens to HomepageBloc state changes
    return BlocBuilder<HomepageBloc, HomepageState>(
      builder: (context, state) {
        // Get selected tab index from state
        final selectedIndex = state is HomepageInitial
            ? state.selectedTabIndex
            : 0;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                // Balance section (includes header)
                _buildBalanceSection(),

                // Action buttons
                _buildActionButtons(),

                // Get Started With SOL section
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildGetStartedSection(),
                  ),
                ),

                // Bottom navigation
                _buildBottomNav(context, selectedIndex),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      constraints: const BoxConstraints(
        minHeight: 180,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Stack(
        children: [
          // Card background image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/assets/images/wallet_background/card_1.png',
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if image doesn't load
                  return Container(
                    color: Colors.grey[900]?.withOpacity(0.5),
                  );
                },
              ),
            ),
          ),
          // Content overlay
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section (Main Wallet, MW icon, menu)
                Row(
                  children: [
                    // Wallet icon and name
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[800]?.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'MW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Main Wallet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Menu icon with notification dot
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.yellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'BALANCE',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '\$0.00',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '+\$0.00 0.00%',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final actions = [
      {'icon': Icons.arrow_downward, 'label': 'Receive', 'isImage': false},
      {'icon': Icons.add_card, 'label': 'Buy', 'isImage': false},
      {'icon': Icons.swap_horiz, 'label': 'Swap', 'isImage': false},
      {'icon': Icons.savings, 'label': 'Stake', 'isImage': true, 'imagePath': 'assets/assets/images/piggy_bank.png'},
      {'icon': Icons.send, 'label': 'Send', 'isImage': false},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((action) {
          return Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  shape: BoxShape.circle,
                ),
                child: action['isImage'] == true
                    ? ClipOval(
                        child: Image.asset(
                          action['imagePath'] as String,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        action['icon'] as IconData,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                action['label'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGetStartedSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Coins illustration
         
          Image.asset('assets/assets/images/empty_wallet.png'),
          const SizedBox(height: 24),
          const Text(
            'Get Started With SOL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Buy SOL to start trading, staking, and exploring. You\'ll need a tiny amount of SOL for each Solana transaction.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            //width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {},
              child: const Text(
                'Buy SOL',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, int selectedIndex) {
    final navItems = [
      {'icon': Icons.description_outlined, 'label': 'Portfolio'},
      {'icon': Icons.bar_chart, 'label': 'Market'},
      {'icon': Icons.swap_horiz, 'label': 'Swap'},
      {'icon': Icons.explore, 'label': 'Explore'},
      {'icon': Icons.settings, 'label': 'Settings'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.5),
        border: Border(
          top: BorderSide(color: Colors.white10, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: navItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isSelected = index == selectedIndex;

          return GestureDetector(
            // Dispatch event to BLoC when tab is tapped
            onTap: () => context.read<HomepageBloc>().add(
                  TabSelectedEvent(index),
                ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item['icon'] as IconData,
                  color: isSelected ? Colors.white : Colors.grey[600],
                  size: 24,
                ),
                const SizedBox(height: 4),
                // Yellow underline that extends beyond text
                Container(
                  height: 2,
                  width: (item['label'] as String).length * 6.0 + 8, // Extends beyond text
                  color: isSelected ? Colors.yellow : Colors.transparent,
                ),
                const SizedBox(height: 2),
                Text(
                  item['label'] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
