import 'package:flutter/material.dart';
import 'package:solfare/core/currency/money.dart';
import 'package:solfare/features/homepage/presentation/widgets/collectibles_section.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';
import 'package:solfare/features/market/presentation/screens/token_detail_screen.dart';
import 'package:solfare/features/staking/domain/entities/stake_account.dart';
import 'package:solfare/features/staking/presentation/screens/stake_account_detail_screen.dart';
import 'package:solfare/features/wallet/domain/entities/nft.dart';
import 'package:solfare/features/wallet/domain/entities/spl_token.dart';
import 'package:solfare/features/wallet/presentation/screens/nft_detail_screen.dart';
import 'package:solfare/l10n/app_localizations.dart';

/// Portfolio content shown when user has a balance — token list, staking,
/// activity sections.
class PortfolioContent extends StatelessWidget {
  final double balanceInSol;
  final String? walletAddress;
  final double solPriceUsd;
  final double solPriceChange24h;
  final VoidCallback? onViewTransactions;
  final VoidCallback? onStartStaking;
  final List<Nft> nfts;
  final List<SplToken> tokens;
  final List<StakeAccount> stakeAccounts;
  final double solPriceForStaking;
  final Widget? afterActivity;

  const PortfolioContent({
    super.key,
    required this.balanceInSol,
    this.walletAddress,
    required this.solPriceUsd,
    required this.solPriceChange24h,
    this.onViewTransactions,
    this.onStartStaking,
    this.nfts = const [],
    this.tokens = const [],
    this.stakeAccounts = const [],
    this.solPriceForStaking = 0.0,
    this.afterActivity,
  });

  @override
  Widget build(BuildContext context) {
    // No invented price: a hardcoded one turns an unknown into a wrong number
    // and renders it as the user's money. Zero totals read as unknown, which
    // is what they are until the price lands — and it now arrives from cache
    // on the first frame.
    final price = solPriceUsd > 0 ? solPriceUsd : 0.0;
    final priceChange = solPriceChange24h;
    final isPositive = priceChange >= 0;
    final solValueUsd = balanceInSol * price;

    final displayTokens = _buildDisplayTokens();
    final tokensValueUsd = displayTokens.fold<double>(0, (sum, t) => sum + t.valueUsd);
    final totalValueUsd = solValueUsd + tokensValueUsd;

    final l = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          _buildTokenHeader(totalValueUsd, l),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),

          _buildTokenCard(context, price, priceChange, isPositive, solValueUsd),

          // Other SPL tokens (plus USDC even at zero balance)
          ...displayTokens.map((t) => Padding(
                padding: const EdgeInsets.only(top: 20),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TokenDetailScreen(
                        token: _splToMarketToken(t),
                        holding: t,
                      ),
                    ),
                  ),
                  child: _buildSplTokenRow(t),
                ),
              )),

          const SizedBox(height: 32),

          _buildSectionHeader(l.stocks),
          const SizedBox(height: 16),
          _buildSectionRow(icon: Icons.bar_chart, text: l.noAssetsYet, buttonText: l.explore, buttonColor: Colors.yellow, textColor: Colors.black, onTap: () {}),

          const SizedBox(height: 32),

          CollectiblesSection(
            nfts: nfts,
            onNftTap: (nft) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NftDetailScreen(nft: nft),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          _buildStakingSection(context, l),

          const SizedBox(height: 32),

          _buildSectionHeader(l.activity),
          const SizedBox(height: 16),
          _buildSectionRow(icon: Icons.history, text: l.transactionHistory, buttonText: l.view, buttonColor: const Color(0xFF2A2D35), textColor: Colors.white, onTap: onViewTransactions ?? () {}),

          if (afterActivity != null) ...[
            const SizedBox(height: 24),
            afterActivity!,
          ],

          const SizedBox(height: 32),

          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A2D35),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () {},
              child: Text(l.customizePortfolio, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTokenHeader(double totalValueUsd, AppLocalizations l) {
    return Row(
      children: [
        Text(l.tokens, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
        Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.white24),
        Text(Money.format(totalValueUsd), style: TextStyle(color: Colors.grey[400], fontSize: 13, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500)),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: Row(
            children: [
              Text(l.viewAll, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w400)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey[500], size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTokenCard(BuildContext context, double price, double priceChange, bool isPositive, double totalValueUsd) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TokenDetailScreen(
              token: MarketToken(
                id: SwapToken.sol.mint,
                name: 'Solana',
                symbol: 'SOL',
                imageUrl: 'https://assets.coingecko.com/coins/images/4128/large/solana.png',
                currentPrice: price,
                decimals: 9,
                isVerified: true,
                stats: {MarketWindow.h24: MarketStats(priceChange: priceChange)},
              ),
              // SOL has no SplToken holding, so this is the only way the detail
              // screen learns the balance its Send action needs.
              solBalance: balanceInSol,
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
            child: ClipOval(
              child: Image.network(
                "https://assets.coingecko.com/coins/images/4128/large/solana.png",
                width: 44, height: 44, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.purple[400]!, Colors.teal[400]!])),
                  child: const Center(child: Text('SOL', style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.bold))),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Solana', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(Money.format(price), style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w400)),
                    const SizedBox(width: 6),
                    Text(
                      '${isPositive ? '+' : ''}${priceChange.toStringAsFixed(2)}%',
                      style: TextStyle(color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFFF5252), fontSize: 11, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Money.format(totalValueUsd), style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500)),
              const SizedBox(height: 3),
              Text(
                '${balanceInSol % 1 == 0 ? balanceInSol.toInt() : balanceInSol.toStringAsFixed(2)} SOL',
                style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Merge fetched SPL tokens with a default USDC entry (zero balance) so users
  // always see the stablecoin in their list.
  List<SplToken> _buildDisplayTokens() {
    final merged = <String, SplToken>{};
    for (final t in tokens) {
      merged[t.mint] = t;
    }
    merged.putIfAbsent(
      WellKnownMints.usdc,
      () => const SplToken(
        mint: WellKnownMints.usdc,
        name: 'USD Coin',
        symbol: 'USDC',
        imageUrl:
            'https://raw.githubusercontent.com/solana-labs/token-list/main/assets/mainnet/EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v/logo.png',
        balance: 0,
        decimals: 6,
        priceUsd: 1,
      ),
    );
    final list = merged.values.toList()
      ..sort((a, b) => b.valueUsd.compareTo(a.valueUsd));
    return list;
  }

  Widget _buildSplTokenRow(SplToken token) {
    final formattedBalance = token.balance == token.balance.roundToDouble()
        ? token.balance.toStringAsFixed(0)
        : token.balance.toStringAsFixed(token.balance < 1 ? 5 : 2);
    final isPositive = token.priceChange24h >= 0;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
          child: ClipOval(
            child: token.imageUrl != null
                ? Image.network(
                    token.imageUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _tokenFallbackAvatar(token.symbol),
                  )
                : _tokenFallbackAvatar(token.symbol),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                token.name,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    token.priceUsd > 0 ? _fmtPrice(token.priceUsd) : token.symbol,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w400),
                  ),
                  if (token.priceChange24h != 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${isPositive ? '+' : ''}${token.priceChange24h.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
                        fontSize: 11,
                        fontFamily: 'FKGroteskSemiMono',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Money.format(token.valueUsd),
              style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 3),
            Text(
              '$formattedBalance ${token.symbol}',
              style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tokenFallbackAvatar(String symbol) {
    final label = symbol.isNotEmpty ? symbol.substring(0, symbol.length.clamp(0, 3)) : '?';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.purple[400]!, Colors.teal[400]!]),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.bold),
      ),
    );
  }

  // A holding described the way the detail screen expects.
  MarketToken _splToMarketToken(SplToken t) {
    return MarketToken(
      id: t.mint,
      name: t.name,
      symbol: t.symbol,
      imageUrl: t.imageUrl ?? '',
      currentPrice: t.priceUsd,
      decimals: t.decimals,
      stats: {MarketWindow.h24: MarketStats(priceChange: t.priceChange24h)},
    );
  }

  String _fmtPrice(double price) => Money.formatPrice(price);

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        const Divider(color: Colors.white10, height: 1),
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
          width: 34, height: 34,
          decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w400))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          onPressed: onTap,
          child: Text(buttonText, style: TextStyle(color: textColor, fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildStakingSection(BuildContext context, AppLocalizations l) {
    if (stakeAccounts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(l.staking),
          const SizedBox(height: 16),
          _buildSectionRow(icon: Icons.savings, text: l.noSolStaked, buttonText: l.startStaking, buttonColor: Colors.yellow, textColor: Colors.black, onTap: onStartStaking ?? () {}),
        ],
      );
    }

    final totalStakedSol = stakeAccounts.fold<double>(0, (sum, a) => sum + a.amountInSol);
    final totalStakedUsd = totalStakedSol * (solPriceForStaking > 0 ? solPriceForStaking : solPriceUsd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l.staking, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
            Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.white24),
            Text(Money.format(totalStakedUsd), style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500)),
            const Spacer(),
            GestureDetector(
              onTap: onStartStaking,
              child: Row(
                children: [
                  Text('View all', style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGrotesk')),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: Colors.grey[500], size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1F26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Staked', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                        Icon(Icons.savings, color: Colors.grey[600], size: 16),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${totalStakedSol.toStringAsFixed(3)} SOL', style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('0.00% APY', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGroteskSemiMono')),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1F26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Rewards', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                        Icon(Icons.nightlight_round, color: Colors.grey[600], size: 16),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('0 SOL', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Last 30 days', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGroteskSemiMono')),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        ...stakeAccounts.map((account) => GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StakeAccountDetailScreen(
                  account: account,
                  solPriceUsd: solPriceForStaking > 0 ? solPriceForStaking : solPriceUsd,
                ),
              ),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.lock_clock, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.state == 'activating' ? 'Activating' : account.state == 'active' ? 'Active' : account.state == 'deactivating' ? 'Deactivating' : 'Inactive',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${account.amountInSol.toStringAsFixed(3)} SOL', style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(Money.format(account.amountInSol * (solPriceForStaking > 0 ? solPriceForStaking : solPriceUsd)), style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGroteskSemiMono')),
                ],
              ),
            ],
          ),
        ),
        )),
      ],
    );
  }
}
