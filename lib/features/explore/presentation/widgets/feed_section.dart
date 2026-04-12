import 'package:flutter/material.dart';
import 'package:solfare/features/explore/domain/entities/crypto_news.dart';

class FeedSection extends StatelessWidget {
  final List<CryptoNews> news;
  final ValueChanged<CryptoNews> onNewsTap;

  const FeedSection({
    super.key,
    required this.news,
    required this.onNewsTap,
  });

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    if (news.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'No news available',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontFamily: 'FKGrotesk',
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 14),
        ...news.take(10).map((item) => _buildNewsRow(item)),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          'Feed',
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
    );
  }

  Widget _buildNewsRow(CryptoNews item) {
    return GestureDetector(
      onTap: () => onNewsTap(item),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source icon placeholder
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  (item.source ?? 'N').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source + time
                  Row(
                    children: [
                      Text(
                        item.source ?? 'Unknown',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 11,
                          fontFamily: 'FKGrotesk',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '  ·  ${_timeAgo(item.publishedAt)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                          fontFamily: 'FKGrotesk',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Title
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                    maxLines: 2,
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
