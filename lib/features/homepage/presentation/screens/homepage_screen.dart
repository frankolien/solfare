import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_bloc.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_event.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_state.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:solfare/features/homepage/presentation/widgets/bottom_nav_bar.dart';
import 'package:lottie/lottie.dart';

class HomepageScreen extends StatefulWidget {
  const HomepageScreen({super.key});

  @override
  State<HomepageScreen> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends State<HomepageScreen> {
  String? _walletAddress;
  bool _hasFetchedPrice = false;
  double _cachedBalanceInSol = 0.0;
  String? _cachedAddress;
  double _cachedSolPriceUsd = 0.0;
  double _cachedSolPriceChange24h = 0.0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadWalletAddress();
  }

  Future<void> _loadWalletAddress() async {
   context.read<WalletBloc>().add(const LoadWalletAddressEvent());

  }

  void _onRefresh(String? address) {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    if (address != null) {
      context.read<WalletBloc>().add(FetchBalanceEvent(address));
    }
    context.read<WalletBloc>().add(const FetchSolPriceEvent());
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _isRefreshing = false);
    });
  }

  void _requestAirdrop() {
    if (_walletAddress != null) {
      // Request 1 SOL airdrop (1,000,000,000 lamports)
      context.read<WalletBloc>().add(
            RequestAirdropEvent(address: _walletAddress!),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    // BlocBuilder listens to HomepageBloc state changes
    return BlocConsumer<WalletBloc, WalletState>(
      listener: (context, state) {
        // Handle side effects (snackbars, navigation, etc.)
        if (state is WalletCleared) {
          // Wallet cleared - navigate to onboarding
          Future.microtask(() {
            if (mounted) {
              context.go(AppRoutes.onboarding);
            }
          });
        } else if (state is AirdropRequested) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Airdrop requested! Balance will update shortly.'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh balance after airdrop
          Future.delayed(const Duration(seconds: 3), () {
            if (_walletAddress != null && mounted) {
              context.read<WalletBloc>().add(
                    FetchBalanceEvent(_walletAddress!),
                  );
            }
          });
        } else if (state is WalletAddressLoaded) {
          setState(() {
            _walletAddress = state.address;
          });
          // Now fetch the balance
          context.read<WalletBloc>().add(FetchBalanceEvent(state.address));
        } else if (state is WalletError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, walletState) {
        // Get balance and address from wallet state
        double balanceInSol = _cachedBalanceInSol; // Use cached balance as default
        bool isLoadingBalance = false;
        String? addressFromState = _cachedAddress ?? _walletAddress;
        double solPriceUsd = _cachedSolPriceUsd;
        double solPriceChange24h = _cachedSolPriceChange24h;

        // Handle different states - can handle multiple states in sequence
        if (walletState is WalletCreated) {
          // Use address from created wallet if available
          addressFromState = walletState.wallet.address;
          if (_walletAddress != addressFromState) {
            // Update local address if different
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _walletAddress = addressFromState;
                });
              }
            });
          }
        }
        
        if (walletState is BalanceFetched) {
          // Cache the balance so it persists when other states are emitted
          balanceInSol = walletState.balanceInSol;
          addressFromState = walletState.address;
          _cachedBalanceInSol = balanceInSol;
          _cachedAddress = addressFromState;
        }
        
        if (walletState is SolPriceFetched) {
          solPriceUsd = walletState.priceUsd;
          solPriceChange24h = walletState.priceChange24h;
          _cachedSolPriceUsd = solPriceUsd;
          _cachedSolPriceChange24h = solPriceChange24h;
          balanceInSol = _cachedBalanceInSol;
        }
        
        if (walletState is WalletLoading) {
          isLoadingBalance = true;
        }

        // Fetch SOL price when screen loads (only once, or on refresh)
        // Don't set _hasFetchedPrice to true immediately - let it fetch
        // The cache in CryptoPriceDataSource will prevent excessive API calls
        if (walletState is! WalletLoading && walletState is! SolPriceFetched) {
          // Only fetch if we haven't received a price yet
          if (!_hasFetchedPrice) {
            _hasFetchedPrice = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.read<WalletBloc>().add(const FetchSolPriceEvent());
              }
            });
          }
        }

        // Use address from state if available, otherwise use stored address
        final currentAddress = addressFromState ?? _walletAddress;

        // Get selected tab index from HomepageBloc
        return BlocBuilder<HomepageBloc, HomepageState>(
          builder: (context, homepageState) {
            final selectedIndex = homepageState is HomepageInitial
                ? homepageState.selectedTabIndex
                : 0;

            return Scaffold(
              backgroundColor: Color(0xFF0a0b12),
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Scrollable content with pull-to-refresh
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollUpdateNotification &&
                              notification.metrics.pixels < -80 &&
                              !_isRefreshing) {
                            _onRefresh(currentAddress);
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          child: Column(
                            children: [
                              // Lottie refresh indicator
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: _isRefreshing ? 50 : 0,
                                child: _isRefreshing
                                    ? Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: Lottie.asset(
                                            'assets/assets/lottie/loading_indicator.json',
                                            repeat: true,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              // Balance section (includes header)
                              _buildBalanceSection(balanceInSol, isLoadingBalance, currentAddress, solPriceUsd, solPriceChange24h),

                              // Action buttons
                              _buildActionButtons(),

                              // Content based on balance
                              if (balanceInSol > 0 && !isLoadingBalance)
                                _buildPortfolioContent(balanceInSol, currentAddress, solPriceUsd, solPriceChange24h)
                              else if (!isLoadingBalance)
                                _buildGetStartedSection(currentAddress),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom navigation (fixed at bottom)
                    BottomNavBar(
                      selectedIndex: selectedIndex,
                      onTap: (index) => context.read<HomepageBloc>().add(
                            TabSelectedEvent(index),
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceSection(double balanceInSol, bool isLoading, String? walletAddress, double solPriceUsd, double solPriceChange24h) {
    final usdValue = solPriceUsd > 0
    ? (balanceInSol * solPriceUsd).toStringAsFixed(2)
    : (balanceInSol * 86.29).toStringAsFixed(2);
    final parts = usdValue.split('.');
    final priceChange = solPriceChange24h;
    final isPositive = priceChange >= 0;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      constraints: const BoxConstraints(
        minHeight: 190,
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header section (Main Wallet, MW icon, menu)
                Row(
                  children: [
                    // Wallet icon and name
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey[800]?.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'MW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontFamily: 'FKGrotesk',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Main Wallet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                     if (walletAddress != null) ...[
                  GestureDetector(
                    onTap: () => _copyWalletAddress(walletAddress),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.copy,
                        color: Colors.grey[400],
                        size: 12,
                      ),
                    ),
                  ),
                ],
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.wallet, color: Colors.white),
                              onPressed: () {},
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            Positioned(
                              right: 9,
                              top: 10,
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
                        //const SizedBox(width: 2),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),

                //    -------------------------------------------------------------  //
                 SizedBox(height:MediaQuery.of(context).size.height * 0.06),
               
                Text(
                  'BALANCE',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                //const SizedBox(height: 6),
                isLoading
                    ? const SizedBox(
                        height: 32,
                        width: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text.rich(
  TextSpan(
    text: '\$${parts[0]}.',
    style: const TextStyle(
      color: Colors.white,
      fontSize: 32,
      fontFamily: 'FKGroteskSemiMono',
      fontWeight: FontWeight.bold,
    ),
    children: [
      TextSpan(
        text: parts[1],
        style: const TextStyle(
          color: Color(0xFFb8bbc1),
          fontSize: 32,
          fontFamily: 'FKGroteskSemiMono',
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  ),
),
                      
                //const SizedBox(height: 2),
                Builder(
                  builder: (context) {
                    final price = solPriceUsd > 0 ? solPriceUsd : 86.29;
                    final dollarChange = balanceInSol * price * (solPriceChange24h / 100);
                    final isPositive = dollarChange >= 0;
                    final changeColor = isPositive
                        ? const Color(0xFFb8bbc1)
                        : const Color(0xFFFF5252);

                    return Row(
                      children: [
                        Text(
                          '${isPositive ? '+' : ''}\$${dollarChange.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 13,
                            fontFamily: 'FKGroteskSemiMono',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${isPositive ? '+' : ''}${solPriceChange24h.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 13,
                            fontFamily: 'FKGroteskSemiMono',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                // Price change section
              


               
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyWalletAddress(String address) {
    Clipboard.setData(ClipboardData(text: address));
    _showCopiedToast();
  }

  void _showCopiedToast() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 200),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1F26),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Copied to clipboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }

  Widget _buildActionButtons() {
    final actions = [
      {'icon': Icons.arrow_downward, 'label': 'Deposit', 'isImage': false},
      //{'icon': Icons.add_card, 'label': 'Buy', 'isImage': false},
      {'icon': Icons.swap_horiz, 'label': 'Swap', 'isImage': false},
      {'icon': Icons.savings, 'label': 'Stake', 'isImage': false},
      {'icon': Icons.send, 'label': 'Send', 'isImage': false},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((action) {
          return Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Color(0xFF23262B),
                  shape: BoxShape.circle,
                ),
                child: action['isImage'] == true
                    ? Padding(
                        padding: const EdgeInsets.all(1),
                        child: Image.asset(
                          action['imagePath'] as String,
                          fit: BoxFit.contain,
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

  Widget _buildPortfolioContent(double balanceInSol, String? walletAddress, double solPriceUsd, double solPriceChange24h) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Tokens section header
          Row(
            children: [
              const Text(
                'Tokens',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                width: 1,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: Colors.white24,
              ),
              Text(
                '\$${(balanceInSol * (solPriceUsd > 0 ? solPriceUsd : 86.29)).toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 13,
                  fontFamily: 'FKGroteskSemiMono',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Row(
                  children: [
                    Text(
                      'View all',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[500],
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(
            color: Colors.white10,
            height: 1,
          ),
          const SizedBox(height: 16),
          // Solana token card
          _buildTokenCard(balanceInSol, solPriceUsd, solPriceChange24h),

          const SizedBox(height: 32),

          // Stocks section
          _buildSectionHeader('Stocks'),
          const SizedBox(height: 16),
          _buildSectionRow(
            icon: Icons.bar_chart,
            text: 'No assets yet',
            buttonText: 'Explore',
           buttonColor: Color(0xFFCCBF00),
            textColor: Colors.black,
            onTap: () {},
          ),

          const SizedBox(height: 32),

          // Staking section
          _buildSectionHeader('Staking'),
          const SizedBox(height: 16),
          _buildSectionRow(
            icon: Icons.savings,
            text: 'No SOL staked yet',
            buttonText: 'Start staking',
            buttonColor: Color(0xFFCCBF00),
            textColor: Colors.black,
            onTap: () {},
          ),

          const SizedBox(height: 32),

          // Activity section
          _buildSectionHeader('Activity'),
          const SizedBox(height: 16),
          _buildSectionRow(
            icon: Icons.history,
            text: 'Transaction history',
            buttonText: 'View',
            buttonColor: const Color(0xFF2A2D35),
            textColor: Colors.white,
            onTap: () {
              if (_walletAddress != null) {
                context.push(AppRoutes.transactionHistory, extra: _walletAddress);
              }
            },
          ),

          const SizedBox(height: 32),

          // Customize portfolio button
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A2D35),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: () {},
              child: const Text(
                'Customize portfolio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTokenCard(double balanceInSol, double solPriceUsd, double solPriceChange24h) {
    final price = solPriceUsd > 0 ? solPriceUsd : 86.29;
    final priceChange = solPriceChange24h;
    final isPositive = priceChange >= 0;
    final totalValueUsd = balanceInSol * price;

    return Row(
      children: [
        // Solana logo — circular black bg
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: Image.network(
              "https://assets.coingecko.com/coins/images/4128/large/solana.png",
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple[400]!, Colors.teal[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'SOL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Name + price row
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Solana',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontFamily: 'FKGroteskSemiMono',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${isPositive ? '+' : ''}${priceChange.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                      fontSize: 11,
                      fontFamily: 'FKGroteskSemiMono',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Value + amount
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${totalValueUsd.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'FKGroteskSemiMono',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${balanceInSol % 1 == 0 ? balanceInSol.toInt() : balanceInSol.toStringAsFixed(2)} SOL',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
                fontFamily: 'FKGroteskSemiMono',
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'FKGrotesk',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(
          color: Colors.white10,
          height: 1,
        ),
      ],
    );
  }

  Widget _buildSectionRow({
    required IconData icon,
    required String text,
    required String buttonText,
    required Color buttonColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: onTap,
          child: Text(
            buttonText,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGetStartedSection(String? walletAddress) {
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
            walletAddress != null
                ? 'Request free test SOL on devnet to start trading, staking, and exploring. You\'ll need a tiny amount of SOL for each Solana transaction.'
                : 'Buy SOL to start trading, staking, and exploring. You\'ll need a tiny amount of SOL for each Solana transaction.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: walletAddress != null ? _requestAirdrop : null,
              child: Text(
                walletAddress != null ? 'Request Test SOL' : 'Buy SOL',
                style: const TextStyle(
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

}
