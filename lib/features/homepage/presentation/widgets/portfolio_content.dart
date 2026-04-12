import 'package:flutter/material.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/presentation/screens/token_detail_screen.dart';

/// Portfolio content shown when user has a balance — token list, staking, activity sections.
class PortfolioContent extends StatelessWidget {
  final double balanceInSol;
  final String? walletAddress;
  final double solPriceUsd;
  final double solPriceChange24h;
  final VoidCallback? onViewTransactions;

  const PortfolioContent({
    super.key,
    required this.balanceInSol,
    this.walletAddress,
    required this.solPriceUsd,
    required this.solPriceChange24h,
    this.onViewTransactions,
  });

  @override
  Widget build(BuildContext context) {
    final price = solPriceUsd > 0 ? solPriceUsd : 86.29;
    final priceChange = solPriceChange24h;
    final isPositive = priceChange >= 0;
    final totalValueUsd = balanceInSol * price;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Token section header
          _buildTokenHeader(totalValueUsd),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),

          // Solana token card
          _buildTokenCard(context, price, priceChange, isPositive, totalValueUsd),

          const SizedBox(height: 32),

          // Stocks section
          _buildSectionHeader('Stocks'),
          const SizedBox(height: 16),
          _buildSectionRow(icon: Icons.bar_chart, text: 'No assets yet', buttonText: 'Explore', buttonColor: Colors.yellow, textColor: Colors.black, onTap: () {}),

          const SizedBox(height: 32),

          // Staking section
          _buildSectionHeader('Staking'),
          const SizedBox(height: 16),
          _buildSectionRow(icon: Icons.savings, text: 'No SOL staked yet', buttonText: 'Start staking', buttonColor: Colors.yellow, textColor: Colors.black, onTap: () {}),

          const SizedBox(height: 32),

          // Activity section
          _buildSectionHeader('Activity'),
          const SizedBox(height: 16),
          _buildSectionRow(icon: Icons.history, text: 'Transaction history', buttonText: 'View', buttonColor: const Color(0xFF2A2D35), textColor: Colors.white, onTap: onViewTransactions ?? () {}),

          const SizedBox(height: 32),

          // Customize portfolio button
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A2D35),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () {},
              child: const Text('Customize portfolio', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTokenHeader(double totalValueUsd) {
    return Row(
      children: [
        const Text('Tokens', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
        Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.white24),
        Text('\$${totalValueUsd.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[400], fontSize: 13, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500)),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: Row(
            children: [
              Text('View all', style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w400)),
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
                id: 'solana',
                name: 'Solana',
                symbol: 'SOL',
                imageUrl: 'https://assets.coingecko.com/coins/images/4128/large/solana.png',
                currentPrice: price,
                priceChangePercentage24h: priceChange,
                marketCap: 0,
                volume24h: 0,
                sparklineData: const [],
              ),
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
                    Text('\$${price.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w400)),
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
              Text('\$${totalValueUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500)),
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
}
