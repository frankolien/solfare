import 'package:flutter/material.dart';
import 'package:solfare/features/explore/domain/entities/dapp_item.dart';
import 'package:solfare/core/util/app_log.dart';

class DiscoverSection extends StatelessWidget {
  final List<DappItem> dapps;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<DappItem> onDappTap;

  const DiscoverSection({
    super.key,
    required this.dapps,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onDappTap,
  });

  static const _categories = ['Featured', 'Earn', 'Ecosystem', 'Memes'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Text(
              'Discover',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey[500], size: 18),
          ],
        ),
        const SizedBox(height: 14),

        // Category tabs
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = cat == selectedCategory;
              return GestureDetector(
                onTap: () => onCategorySelected(cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.grey[800] : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.white12,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[500],
                      fontSize: 12,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),

        // dApp list
        ...dapps.map((dapp) => _buildDappRow(dapp)),
      ],
    );
  }

  Widget _buildDappRow(DappItem dapp) {
    return GestureDetector(
      onTap: () => onDappTap(dapp),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[850] ?? Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  dapp.iconUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    debugLog('[Discover] Loading icon: ${dapp.iconUrl}');
                    if (loadingProgress == null) {
                      debugLog('[Discover] Icon loaded OK: ${dapp.name}');
                      return child;
                    }
                    return Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, error, ___) {
                    debugLog('[Discover] Icon FAILED for ${dapp.name}: $error');
                    debugLog('[Discover] URL was: ${dapp.iconUrl}');
                    return Center(
                      child: Text(
                        dapp.name.substring(0, 1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'FKGrotesk',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dapp.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dapp.description,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
