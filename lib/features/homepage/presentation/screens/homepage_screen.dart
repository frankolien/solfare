import 'package:bs58/bs58.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_bloc.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_event.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_state.dart';
import 'package:solfare/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:solfare/features/wallet/data/datasource/wallet_local_datasource.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';

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

  @override
  void initState() {
    super.initState();
    _loadWalletAddress();
  }

  Future<void> _loadWalletAddress() async {
    try {
      final repository = WalletRepositoryImpl(
        localDataSource: WalletLocalDataSourceImpl(),
      );
      final address = await repository.getSavedAddress();
      if (address != null && address.isNotEmpty && mounted) {
        // Trim and validate address format
        // Solana addresses are base58-encoded, typically 32-50 characters
        final trimmedAddress = address.trim();
        
        // Remove any non-printable characters
        final cleanAddress = trimmedAddress.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
        
        // Validate: Solana addresses are typically 32-50 characters (base58)
        if (cleanAddress.length >= 32 && cleanAddress.length <= 50) {
          // Validate it's base58 (only contains valid base58 characters)
          final base58Regex = RegExp(r'^[1-9A-HJ-NP-Za-km-z]+$');
          if (base58Regex.hasMatch(cleanAddress)) {
            // Decode and validate the address is exactly 32 bytes (Solana public key size)
            try {
              final decodedBytes = base58.decode(cleanAddress);
              if (decodedBytes.length != 32) {
                // Invalid address - not 32 bytes when decoded
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Invalid wallet address detected. Tap "Clear Wallet" to fix.'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'Clear Wallet',
                        textColor: Colors.white,
                        onPressed: () {
                          context.read<WalletBloc>().add(const ClearWalletEvent());
                        },
                      ),
                    ),
                  );
                  debugPrint('Invalid wallet address: decoded length is ${decodedBytes.length} bytes, expected 32 bytes');
                }
                return;
              }
              
              // Address is valid - use it
              setState(() {
                _walletAddress = cleanAddress;
              });
              // Fetch balance when address is loaded
              context.read<WalletBloc>().add(FetchBalanceEvent(cleanAddress));
              debugPrint('Wallet address loaded: ${cleanAddress.substring(0, 8)}... (length: ${cleanAddress.length}, decoded: 32 bytes)');
            } catch (e) {
              // Failed to decode base58
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Invalid wallet address: failed to decode - $e. Please recreate your wallet.'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
                debugPrint('Invalid wallet address: failed to decode base58 - $e');
              }
            }
          } else {
            // Invalid base58 characters
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invalid wallet address: contains invalid characters'),
                  backgroundColor: Colors.red,
                ),
              );
              debugPrint('Invalid wallet address: contains non-base58 characters');
            }
          }
        } else {
          // Invalid address length
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid wallet address format (length: ${cleanAddress.length}, expected 32-50)'),
                backgroundColor: Colors.red,
              ),
            );
            debugPrint('Invalid wallet address format (length: ${cleanAddress.length})');
            debugPrint('Address preview: ${cleanAddress.substring(0, cleanAddress.length > 20 ? 20 : cleanAddress.length)}...');
          }
        }
      }
    } catch (e) {
      // Handle error silently or show debug message
      if (mounted) {
        debugPrint('Error loading wallet address: $e');
      }
    }
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
        double solPriceUsd = 0.0;
        double solPriceChange24h = 0.0;

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
          // Price fetched - don't lose the cached balance
          solPriceUsd = walletState.priceUsd;
          solPriceChange24h = walletState.priceChange24h;
          // Keep using cached balance
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
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Column(
                  children: [
                    // Scrollable content with pull-to-refresh
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          print('🔄 [Homepage] Pull-to-refresh triggered');
                          final address = currentAddress;
                          // Refresh balance if address is available
                          if (address != null) {
                            context.read<WalletBloc>().add(FetchBalanceEvent(address));
                          }
                          // Refresh SOL price
                          context.read<WalletBloc>().add(const FetchSolPriceEvent());
                          // Wait a bit for the requests to complete
                          await Future.delayed(const Duration(milliseconds: 500));
                        },
                        color: Colors.yellow,
                        backgroundColor: Colors.grey[900],
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(), // Enable scrolling even when content is small
                          child: Column(
                            children: [
                              // Balance section (includes header)
                              _buildBalanceSection(balanceInSol, isLoadingBalance, currentAddress, solPriceUsd),

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
                    _buildBottomNav(context, selectedIndex),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceSection(double balanceInSol, bool isLoading, String? walletAddress, double solPriceUsd) {
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
            padding: const EdgeInsets.all(16),
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
                    const SizedBox(width: 7),
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
                isLoading
                    ? const SizedBox(
                        height: 32,
                        width: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        solPriceUsd > 0
                            ? '\$${(balanceInSol * solPriceUsd).toStringAsFixed(2)}'
                            : '\$${(balanceInSol * 86.29).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          
                        ),
                      ),
                //const SizedBox(height: 2),
                
                // Wallet address section (if available)
                if (walletAddress != null) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _copyWalletAddress(walletAddress),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            walletAddress,
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.copy,
                          color: Colors.grey[400],
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyWalletAddress(String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wallet address copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
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

  Widget _buildPortfolioContent(double balanceInSol, String? walletAddress, double solPriceUsd, double solPriceChange24h) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Tokens section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tokens ${balanceInSol.toStringAsFixed(2)} SOL',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View all >',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Solana token card
          _buildTokenCard(balanceInSol, solPriceUsd, solPriceChange24h),
          const SizedBox(height: 32),
          const SizedBox(height: 40), // Extra padding at bottom
        ],
      ),
    );
  }

  Widget _buildTokenCard(double balanceInSol, double solPriceUsd, double solPriceChange24h) {
    // Use real price if available, otherwise fallback to approximate
    final price = solPriceUsd > 0 ? solPriceUsd : 86.29;
    final priceChange = solPriceChange24h;
    final isPositive = priceChange >= 0;
    final totalValueUsd = balanceInSol * price;
    
    return Row(
      children: [
        // Solana logo
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
             "https://assets.coingecko.com/coins/images/4128/large/solana.png",
              
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to gradient if image doesn't exist
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple[400]!, Colors.teal[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'SOL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Solana',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isPositive ? Colors.green : Colors.red).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${isPositive ? '+' : ''}${priceChange.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${totalValueUsd.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${balanceInSol.toStringAsFixed(8)} SOL',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
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
