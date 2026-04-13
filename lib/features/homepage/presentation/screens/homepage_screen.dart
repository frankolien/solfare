import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_bloc.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_event.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_state.dart';
import 'package:solfare/features/homepage/presentation/widgets/balance_card.dart';
import 'package:solfare/features/homepage/presentation/widgets/action_buttons.dart';
import 'package:solfare/features/homepage/presentation/widgets/bottom_nav_bar.dart';
import 'package:solfare/features/homepage/presentation/widgets/get_started_section.dart';
import 'package:solfare/features/homepage/presentation/widgets/portfolio_content.dart';
import 'package:solfare/features/market/presentation/screens/market_screen.dart';
import 'package:solfare/features/swap/presentation/screens/swap_screen.dart';
import 'package:solfare/features/explore/presentation/screens/explore_screen.dart';
import 'package:solfare/features/settings/presentation/screens/settings_screen.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:solfare/features/wallet/domain/entities/nft.dart';
import 'package:solfare/features/wallet/presentation/screens/my_wallets_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/edit_background_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/qr_scanner_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/receive_screen.dart';
import 'package:solfare/features/wallet/presentation/screens/rename_wallet_screen.dart';

class HomepageScreen extends StatefulWidget {
  const HomepageScreen({super.key});

  @override
  State<HomepageScreen> createState() => _HomepageScreenState();
}

class _HomepageScreenState extends State<HomepageScreen> {
  String? _walletAddress;
  bool _hasFetchedPrice = false;
  bool _isRefreshing = false;

  // Cached values so data persists across BLoC state changes
  double _cachedBalanceInSol = 0.0;
  String? _cachedAddress;
  double _cachedSolPriceUsd = 0.0;
  double _cachedSolPriceChange24h = 0.0;
  List<Nft> _cachedNfts = [];
  bool _hasFetchedNfts = false;

  // Wallet customization
  String _walletName = 'Main Wallet';
  String _cardBackground = 'card_1.png';

  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const LoadWalletAddressEvent());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCustomization());
  }

  Future<void> _loadCustomization() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _walletName = prefs.getString('wallet_name') ?? 'Main Wallet';
        _cardBackground = prefs.getString('card_background') ?? 'card_1.png';
      });
    } catch (_) {
      // Platform not ready yet, keep defaults
    }
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
      context.read<WalletBloc>().add(RequestAirdropEvent(address: _walletAddress!));
    }
  }

  void _showDepositSheet(BuildContext context, String address) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF0E1014),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
            ),

            // Receive crypto option
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ReceiveScreen(walletAddress: address)),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFF1C1F26), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.qr_code, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Receive crypto', style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text('Transfer from an exchange or wallet', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk')),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _handleCardAction(String action) {
    switch (action) {
      case 'scan_qr':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QrScannerScreen()),
        );
      case 'rename':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RenameWalletScreen(currentName: _walletName)),
        ).then((newName) async {
          if (newName != null && newName is String) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('wallet_name', newName);
            if (mounted) setState(() => _walletName = newName);
          }
        });
      case 'edit_bg':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EditBackgroundScreen(currentCard: _cardBackground)),
        ).then((card) async {
          if (card != null && card is String) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('card_background', card);
            if (mounted) setState(() => _cardBackground = card);
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalletBloc, WalletState>(
      listener: _handleWalletState,
      builder: (context, walletState) {
        // Resolve current values from state + cache
        final data = _resolveData(walletState);

        return BlocBuilder<HomepageBloc, HomepageState>(
          builder: (context, homepageState) {
            final selectedIndex = homepageState is HomepageInitial
                ? homepageState.selectedTabIndex
                : 0;

            return Scaffold(
              backgroundColor: const Color(0xFF0a0b12),
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Expanded(child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: _buildTabContent(selectedIndex, data),
                    )),
                    BottomNavBar(
                      selectedIndex: selectedIndex,
                      onTap: (index) => context.read<HomepageBloc>().add(TabSelectedEvent(index)),
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

  // ── State Handling ──

  void _handleWalletState(BuildContext context, WalletState state) {
    if (state is WalletCleared) {
      Future.microtask(() {
        if (mounted) context.go(AppRoutes.onboarding);
      });
    } else if (state is AirdropRequested) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Airdrop requested! Balance will update shortly.'), backgroundColor: Colors.green),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (_walletAddress != null && mounted) {
          context.read<WalletBloc>().add(FetchBalanceEvent(_walletAddress!));
        }
      });
    } else if (state is WalletAddressLoaded) {
      setState(() => _walletAddress = state.address);
      context.read<WalletBloc>().add(FetchBalanceEvent(state.address));
      // Fetch NFTs once
      if (!_hasFetchedNfts) {
        _hasFetchedNfts = true;
        context.read<WalletBloc>().add(FetchNftsEvent(state.address));
      }
    } else if (state is NftsFetched) {
      setState(() => _cachedNfts = state.nfts);
    } else if (state is WalletCustomizationLoaded) {
      setState(() {
        _walletName = state.walletName;
        _cardBackground = state.cardBackground;
      });
    } else if (state is WalletError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${state.message}'), backgroundColor: Colors.red),
      );
    }
  }

  /// Extracts current display values from BLoC state, falling back to cached values.
  _HomeData _resolveData(WalletState walletState) {
    double balanceInSol = _cachedBalanceInSol;
    bool isLoadingBalance = false;
    String? address = _cachedAddress ?? _walletAddress;
    double solPriceUsd = _cachedSolPriceUsd;
    double solPriceChange24h = _cachedSolPriceChange24h;

    if (walletState is WalletCreated) {
      address = walletState.wallet.address;
      if (_walletAddress != address) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _walletAddress = address);
        });
      }
    }

    if (walletState is BalanceFetched) {
      balanceInSol = walletState.balanceInSol;
      address = walletState.address;
      _cachedBalanceInSol = balanceInSol;
      _cachedAddress = address;
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

    // Fetch price once on first relevant state
    if (walletState is! WalletLoading && walletState is! SolPriceFetched && !_hasFetchedPrice) {
      _hasFetchedPrice = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<WalletBloc>().add(const FetchSolPriceEvent());
      });
    }

    return _HomeData(
      balanceInSol: balanceInSol,
      isLoadingBalance: isLoadingBalance,
      address: address ?? _walletAddress,
      solPriceUsd: solPriceUsd,
      solPriceChange24h: solPriceChange24h,
    );
  }

  // ── Tab Content ──

  Widget _buildTabContent(int selectedIndex, _HomeData data) {
    switch (selectedIndex) {
      case 1: return const MarketScreen();
      case 2: return const SwapScreen();
      case 3: return const ExploreScreen();
      case 4: return const SettingsScreen();
      default: return _buildPortfolioTab(data);
    }
  }

  Widget _buildPortfolioTab(_HomeData data) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.metrics.pixels < -80 &&
            !_isRefreshing) {
          _onRefresh(data.address);
        }
        return false;
      },
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        child: Column(
          children: [
            // Pull-to-refresh lottie
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _isRefreshing ? 50 : 0,
              child: _isRefreshing
                  ? Center(child: SizedBox(width: 22, height: 22, child: Lottie.asset('assets/assets/lottie/loading_indicator.json', repeat: true)))
                  : const SizedBox.shrink(),
            ),

            BalanceCard(
              balanceInSol: data.balanceInSol,
              isLoading: data.isLoadingBalance,
              walletAddress: data.address,
              solPriceUsd: data.solPriceUsd,
              solPriceChange24h: data.solPriceChange24h,
              walletName: _walletName,
              cardBackground: _cardBackground,
              onWalletTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => EditBackgroundScreen(currentCard: _cardBackground)),
                ).then((card) async {
                  if (card != null && card is String) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('card_background', card);
                    if (mounted) {
                      setState(() => _cardBackground = card);
                    }
                  }
                });
              },
              onMoreAction: (action) => _handleCardAction(action),
              onMwTap: () {
                if (_walletAddress != null) {
                  final usdValue = _cachedBalanceInSol * (_cachedSolPriceUsd > 0 ? _cachedSolPriceUsd : 0);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MyWalletsScreen(
                        walletAddress: _walletAddress!,
                        balanceUsd: usdValue,
                        priceChange24h: _cachedSolPriceChange24h,
                        walletName: _walletName,
                        cardBackground: _cardBackground,
                      ),
                    ),
                  ).then((_) => _loadCustomization());
                }
              },
            ),

            ActionButtons(
              onDeposit: () {
                if (_walletAddress != null) {
                  _showDepositSheet(context, _walletAddress!);
                }
              },
              onStake: () {
                if (_walletAddress != null) {
                  context.push(AppRoutes.stakeSol, extra: {
                    'address': _walletAddress,
                    'balance': _cachedBalanceInSol,
                    'priceUsd': _cachedSolPriceUsd,
                  });
                }
              },
              onSend: () {
                if (_walletAddress != null) {
                  context.push(AppRoutes.sendSol, extra: {
                    'address': _walletAddress,
                    'balance': _cachedBalanceInSol,
                    'priceUsd': _cachedSolPriceUsd,
                  });
                }
              },
            ),

            if (data.balanceInSol > 0 && !data.isLoadingBalance)
              PortfolioContent(
                balanceInSol: data.balanceInSol,
                walletAddress: data.address,
                solPriceUsd: data.solPriceUsd,
                solPriceChange24h: data.solPriceChange24h,
                nfts: _cachedNfts,
                onStartStaking: () {
                  if (_walletAddress != null) {
                    context.push(AppRoutes.stakeSol, extra: {
                      'address': _walletAddress,
                      'balance': _cachedBalanceInSol,
                      'priceUsd': _cachedSolPriceUsd,
                    });
                  }
                },
                onViewTransactions: () {
                  if (_walletAddress != null) {
                    context.push(AppRoutes.transactionHistory, extra: _walletAddress);
                  }
                },
              )
            else if (!data.isLoadingBalance)
              GetStartedSection(
                walletAddress: data.address,
                onRequestAirdrop: _requestAirdrop,
              ),
          ],
        ),
      ),
    );
  }
}

/// Simple data class to pass resolved state values around.
class _HomeData {
  final double balanceInSol;
  final bool isLoadingBalance;
  final String? address;
  final double solPriceUsd;
  final double solPriceChange24h;

  const _HomeData({
    required this.balanceInSol,
    required this.isLoadingBalance,
    this.address,
    required this.solPriceUsd,
    required this.solPriceChange24h,
  });
}
