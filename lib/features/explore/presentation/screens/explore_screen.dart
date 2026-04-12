import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solfare/features/explore/domain/entities/dapp_item.dart';
import 'package:solfare/features/explore/presentation/bloc/explore_bloc.dart';
import 'package:solfare/features/explore/presentation/bloc/explore_event.dart';
import 'package:solfare/features/explore/presentation/bloc/explore_state.dart';
import 'package:solfare/features/explore/presentation/screens/dapp_browser_screen.dart';
import 'package:solfare/features/explore/presentation/widgets/discover_section.dart';
import 'package:solfare/features/explore/presentation/widgets/feed_section.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ExploreBloc>().add(const FetchNewsEvent());
  }

  void _openDapp(DappItem dapp) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DappBrowserScreen(
          initialUrl: dapp.url,
          title: dapp.name,
        ),
      ),
    );
  }

  void _openBrowser(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DappBrowserScreen(initialUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0b12),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: BlocBuilder<ExploreBloc, ExploreState>(
                builder: (context, state) {
                  if (state is ExploreLoading) {
                    return _buildShimmer();
                  }
                  if (state is ExploreLoaded) {
                    return _buildContent(state);
                  }
                  if (state is ExploreError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'FKGrotesk'),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          // MW avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'MW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Search / URL bar
          Expanded(
            child: GestureDetector(
              onTap: _showUrlInputSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1F26),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey[500], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Search or type URL',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontFamily: 'FKGrotesk',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // More menu
          GestureDetector(
            onTap: () {},
            child: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
          ),

          const SizedBox(width: 10),

          // Tab count badge
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[600]!, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '1',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                  fontFamily: 'FKGroteskSemiMono',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ExploreLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Discover — dApp directory with category tabs
          DiscoverSection(
            dapps: state.dapps,
            selectedCategory: state.selectedCategory,
            onCategorySelected: (category) {
              context.read<ExploreBloc>().add(SelectCategoryEvent(category));
            },
            onDappTap: _openDapp,
          ),

          const SizedBox(height: 32),

          // Feed — real news from CryptoPanic
          FeedSection(
            news: state.news,
            onNewsTap: (news) => _openBrowser(news.url),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          // Discover title shimmer
          Container(width: 70, height: 14, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 16),
          // Category tabs shimmer
          Row(
            children: List.generate(4, (_) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 60,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )),
          ),
          const SizedBox(height: 18),
          // dApp rows shimmer
          ...List.generate(5, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(12))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 100, height: 10, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Container(width: 160, height: 8, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 32),
          // Feed title shimmer
          Container(width: 40, height: 14, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 16),
          // News rows shimmer
          ...List.generate(4, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 80, height: 8, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 6),
                      Container(width: double.infinity, height: 10, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 4),
                      Container(width: 200, height: 10, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4))),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _showUrlInputSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          decoration: const BoxDecoration(
            color: Color(0xFF0E1014),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // URL input
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'FKGrotesk',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search or type URL',
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontFamily: 'FKGrotesk',
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 18),
                  ),
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (value) {
                    Navigator.pop(context);
                    _navigateToUrl(value);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToUrl(String input) {
    String url = input.trim();
    if (url.isEmpty) return;

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.')) {
        url = 'https://$url';
      } else {
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }

    _openBrowser(url);
  }
}
