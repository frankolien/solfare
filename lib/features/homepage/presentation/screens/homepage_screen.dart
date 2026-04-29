import 'package:flutter/cupertino.dart'
    show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/features/homepage/data/portfolio_history.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_bloc.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_event.dart';
import 'package:solfare/features/homepage/presentation/bloc/homepage_state.dart';
import 'package:solfare/features/homepage/presentation/widgets/balance_card.dart';
import 'package:solfare/features/homepage/presentation/widgets/action_buttons.dart';
import 'package:solfare/features/homepage/presentation/widgets/bottom_nav_bar.dart';
import 'package:solfare/features/homepage/presentation/widgets/add_wallet_sheet.dart';
import 'package:solfare/features/homepage/presentation/widgets/get_started_section.dart';
import 'package:solfare/features/homepage/presentation/widgets/portfolio_chart.dart';
import 'package:solfare/features/homepage/presentation/widgets/wallet_card_swiper.dart';
import 'package:solfare/features/homepage/presentation/widgets/portfolio_content.dart';
import 'package:solfare/features/market/presentation/screens/market_screen.dart';
import 'package:solfare/features/swap/presentation/screens/swap_screen.dart';
import 'package:solfare/features/explore/presentation/screens/explore_screen.dart';
import 'package:solfare/features/settings/presentation/screens/settings_screen.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:solfare/features/staking/domain/entities/stake_account.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_bloc.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_event.dart';
import 'package:solfare/features/staking/presentation/bloc/staking_state.dart';
import 'package:solfare/features/wallet/domain/entities/nft.dart';
import 'package:solfare/features/wallet/domain/entities/spl_token.dart';
import 'package:solfare/features/wallet/domain/entities/wallet_account.dart';
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

  // Cached values so data persists across BLoC state changes
  double _cachedBalanceInSol = 0.0;
  String? _cachedAddress;
  double _cachedSolPriceUsd = 0.0;
  double _cachedSolPriceChange24h = 0.0;
  List<Nft> _cachedNfts = [];
  bool _hasFetchedNfts = false;
  List<SplToken> _cachedTokens = [];
  bool _hasFetchedTokens = false;
  List<WalletAccount> _wallets = const [];
  String? _activeWalletId;
  List<StakeAccount> _cachedStakeAccounts = [];
  bool _hasFetchedStakes = false;

  // Wallet customization
  String _walletName = 'Main Wallet';
  String _cardBackground = 'card_1.png';

  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(const LoadWalletAddressEvent());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCustomization());
  }

  void _loadCustomization() {
    // Bloc resolves the active wallet's name + card from the multi-wallet
    // store and fires WalletCustomizationLoaded back, which _handleWalletState
    // captures into _walletName / _cardBackground.
    if (mounted) {
      context.read<WalletBloc>().add(const LoadWalletCustomizationEvent());
    }
  }

  // CupertinoSliverRefreshControl keeps the indicator slot open for as
  // long as this Future is pending. ~1.2s matches Solflare's deliberate
  // "we're working" feel even when data lands sooner.
  Future<void> _onRefresh(String? address) async {
    final bloc = context.read<WalletBloc>();
    if (address != null) {
      bloc.add(FetchBalanceEvent(address));
      bloc.add(FetchNftsEvent(address));
      bloc.add(FetchTokensEvent(address));
    }
    bloc.add(const FetchSolPriceEvent());
    await Future.delayed(const Duration(milliseconds: 1200));
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
        ).then((newName) {
          if (newName != null && newName is String && mounted) {
            context.read<WalletBloc>().add(UpdateWalletNameEvent(newName));
          }
        });
      case 'edit_bg':
        if (_activeWalletId == null) break;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EditBackgroundScreen(
              currentCard: _cardBackground,
              walletId: _activeWalletId!,
            ),
          ),
        ).then((card) {
          if (card != null && card is String && mounted) {
            context.read<WalletBloc>().add(UpdateCardBackgroundEvent(card));
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StakingBloc, StakingState>(
      listener: (context, stakingState) {
        if (stakingState is StakeAccountsFetched) {
          setState(() => _cachedStakeAccounts = stakingState.accounts);
        } else if (stakingState is StakeDeactivated || stakingState is StakeWithdrawn) {
          // Re-fetch stake accounts after unstake/withdraw
          if (_walletAddress != null) {
            context.read<StakingBloc>().add(FetchStakeAccountsEvent(_walletAddress!));
          }
          // Also refresh balance
          if (_walletAddress != null) {
            context.read<WalletBloc>().add(FetchBalanceEvent(_walletAddress!));
          }
        }
      },
      child: BlocConsumer<WalletBloc, WalletState>(
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
    ),
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
      // Fetch SPL tokens once
      if (!_hasFetchedTokens) {
        _hasFetchedTokens = true;
        context.read<WalletBloc>().add(FetchTokensEvent(state.address));
      }
      // Fetch stake accounts once
      if (!_hasFetchedStakes) {
        _hasFetchedStakes = true;
        context.read<StakingBloc>().add(FetchStakeAccountsEvent(state.address));
      }
    } else if (state is NftsFetched) {
      setState(() => _cachedNfts = state.nfts);
    } else if (state is TokensFetched) {
      setState(() => _cachedTokens = state.tokens);
    } else if (state is WalletsLoaded) {
      setState(() {
        _wallets = state.wallets;
        _activeWalletId = state.activeId;
      });
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
      // Defense in depth: ignore balance updates whose address doesn't
      // match the wallet we're displaying. The bloc already drops these
      // for the active wallet, but switching wallets in quick succession
      // can still race. Better to keep the previous (stale) balance for
      // a few frames than briefly flash the wrong wallet's number.
      final activeAddr = _walletAddress;
      if (activeAddr == null || walletState.address == activeAddr) {
        balanceInSol = walletState.balanceInSol;
        address = walletState.address;
        _cachedBalanceInSol = balanceInSol;
        _cachedAddress = address;
      }
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

    // Record a portfolio snapshot whenever we have a complete picture
    // (balance AND price known). PortfolioHistory dedupes to one entry/hour
    // so spamming this here is cheap.
    if (balanceInSol > 0 && solPriceUsd > 0 && (address ?? _walletAddress) != null) {
      final tokensUsd = _cachedTokens.fold<double>(0, (sum, t) => sum + t.valueUsd);
      final totalUsd = (balanceInSol * solPriceUsd) + tokensUsd;
      PortfolioHistory.instance.record(address ?? _walletAddress!, totalUsd);
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

  /// The wallet card region — swipeable between wallets with a trailing
  /// "add wallet" slot. When only one wallet is installed the list is still
  /// two pages long (the wallet + the add slot) so the swipe affordance
  /// stays discoverable.
  Widget _buildWalletArea(BuildContext context, _HomeData data) {
    // No wallets yet — fall back to a single static BalanceCard so the
    // initial render before WalletsLoaded arrives doesn't flicker.
    if (_wallets.isEmpty) {
      return _buildBalanceCard(
        data: data,
        name: _walletName,
        card: _cardBackground,
      );
    }

    return WalletCardSwiper(
      wallets: _wallets,
      activeWalletId: _activeWalletId,
      onWalletSelected: (id) {
        context.read<WalletBloc>().add(SwitchWalletEvent(id));
      },
      onAddWallet: () => showAddWalletSheet(context),
      walletBuilder: (ctx, wallet) {
        final isActive = wallet.id == _activeWalletId;
        // Only the active wallet displays live balance/price data — inactive
        // pages render their card with dash placeholders until switched to.
        return _buildBalanceCard(
          data: data,
          name: wallet.name,
          card: wallet.cardBackground,
          forcedAddress: wallet.address,
          showData: isActive,
        );
      },
    );
  }

  Widget _buildBalanceCard({
    required _HomeData data,
    required String name,
    required String card,
    String? forcedAddress,
    bool showData = true,
  }) {
    return BalanceCard(
      balanceInSol: showData ? data.balanceInSol : 0,
      isLoading: showData ? data.isLoadingBalance : false,
      walletAddress: forcedAddress ?? data.address,
      solPriceUsd: showData ? data.solPriceUsd : 0,
      solPriceChange24h: showData ? data.solPriceChange24h : 0,
      walletName: name,
      cardBackground: card,
      onWalletTap: () {
        if (_activeWalletId == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EditBackgroundScreen(
              currentCard: card,
              walletId: _activeWalletId!,
            ),
          ),
        ).then((picked) {
          if (picked != null && picked is String && mounted) {
            context.read<WalletBloc>().add(UpdateCardBackgroundEvent(picked));
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
    );
  }

  Widget _buildPortfolioTab(_HomeData data) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // Solflare-style pull-to-refresh. The builder receives live pull
        // progress — we use it to fade and scale the Lottie naturally as
        // the user drags, and keep it playing while refresh runs.
        CupertinoSliverRefreshControl(
          refreshTriggerPullDistance: 100,
          refreshIndicatorExtent: 60,
          onRefresh: () => _onRefresh(data.address),
          builder: (context, mode, pulled, trigger, indicator) {
            final visible = pulled > 0 || mode == RefreshIndicatorMode.refresh;
            if (!visible) return const SizedBox.shrink();
            final opacity = (pulled / trigger).clamp(0.0, 1.0);
            return Center(
              child: Opacity(
                opacity: mode == RefreshIndicatorMode.refresh ? 1.0 : opacity,
                child: Lottie.asset(
                  'assets/assets/lottie/loading_indicator.json',
                  repeat: true,
                  width: 28,
                  height: 28,
                ),
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildWalletArea(context, data),
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
                  tokens: _cachedTokens,
                  stakeAccounts: _cachedStakeAccounts,
                  solPriceForStaking: _cachedSolPriceUsd,
                  afterActivity: data.address != null
                      ? PortfolioChart(
                          address: data.address!,
                          currentUsdValue: data.balanceInSol *
                                  (data.solPriceUsd > 0 ? data.solPriceUsd : 0) +
                              _cachedTokens.fold<double>(
                                  0, (sum, t) => sum + t.valueUsd),
                        )
                      : null,
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
                      context.push(AppRoutes.transactionHistory,
                          extra: _walletAddress);
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
      ],
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
