import 'package:flutter/material.dart';
import 'package:solfare/features/wallet/domain/entities/nft.dart';

class CollectiblesSection extends StatelessWidget {
  final List<Nft> nfts;

  const CollectiblesSection({super.key, required this.nfts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Text(
              'Collectibles',
              style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {},
              child: Row(
                children: [
                  Text('View all', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk')),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: Colors.grey[500], size: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.white10, height: 1),
        const SizedBox(height: 12),

        if (nfts.isEmpty)
          // Empty state
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No collectibles yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 11, fontFamily: 'FKGrotesk'),
              ),
            ),
          )
        else
          // NFT grid — 2 columns, horizontal scroll
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: nfts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _buildNftCard(nfts[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildNftCard(Nft nft) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: const Color(0xFF0E1014),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NFT image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: nft.imageUrl != null
                ? Image.network(
                    nft.imageUrl!,
                    width: 140,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),

          // Name
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              nft.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 140,
      height: 120,
      color: Colors.grey[900],
      child: Icon(Icons.image, color: Colors.grey[700], size: 32),
    );
  }
}
