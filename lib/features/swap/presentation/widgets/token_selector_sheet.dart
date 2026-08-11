import 'dart:async';

import 'package:flutter/material.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/market/data/datasource/jupiter_token_datasource.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';

class TokenSelectorSheet extends StatefulWidget {
  final List<SwapToken> tokens;
  final SwapToken? selectedToken;

  const TokenSelectorSheet({
    super.key,
    required this.tokens,
    this.selectedToken,
  });

  @override
  State<TokenSelectorSheet> createState() => _TokenSelectorSheetState();
}

class _TokenSelectorSheetState extends State<TokenSelectorSheet> {
  final _searchController = TextEditingController();
  final _tokens = JupiterTokenDataSource();

  // Bumped per keystroke; a response whose id no longer matches is stale.
  int _searchSeq = 0;
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  List<SwapToken> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.tokens;
  }

  void _onSearch(String query) {
    _searchSeq++;
    final needle = query.trim().toLowerCase();
    setState(() {
      _searching = false;
      _filtered = needle.isEmpty
          ? widget.tokens
          : widget.tokens
              .where((t) =>
                  t.symbol.toLowerCase().contains(needle) ||
                  t.name.toLowerCase().contains(needle) ||
                  t.mint.toLowerCase() == needle)
              .toList();
    });

    // Nothing local: ask Jupiter, so a token the wallet does not hold and the
    // curated list never named is still reachable. Anything shorter than two
    // characters matches half the chain.
    if (_filtered.isEmpty && needle.length >= 2) {
      unawaited(_searchRemote(needle, _searchSeq));
    }
  }

  Future<void> _searchRemote(String query, int seq) async {
    setState(() => _searching = true);
    try {
      final found = await _tokens.search(query);
      // A slower earlier search must not overwrite a later one's results.
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searching = false;
        _filtered = [
          for (final t in found)
            SwapToken(
              mint: t.id,
              symbol: t.symbol,
              name: t.name,
              decimals: t.decimals,
              logoUrl: t.imageUrl,
              priceUsd: t.currentPrice,
            ),
        ];
      });
    } catch (e) {
      debugLog('[Swap] token search failed: $e');
      if (mounted && seq == _searchSeq) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0E1014),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Text(
            'Select token',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search, color: Colors.grey[500], size: 18),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk'),
                      decoration: InputDecoration(
                        hintText: 'Search token name or mint',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'FKGrotesk'),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      ),
                      onChanged: _onSearch,
                      autofocus: true,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: _searching && _filtered.isEmpty
                ? const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.yellow),
                    ),
                  )
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No token found',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                            fontFamily: 'FKGrotesk',
                          ),
                        ),
                      )
                    : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final token = _filtered[index];
                final isSelected = widget.selectedToken?.mint == token.mint;

                return GestureDetector(
                  onTap: () => Navigator.pop(context, token),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        ClipOval(
                          child: token.logoUrl != null
                              ? Image.network(
                                  token.logoUrl!,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildFallbackIcon(token),
                                )
                              : _buildFallbackIcon(token),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                token.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.yellow : Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'FKGrotesk',
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                token.symbol,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 10,
                                  fontFamily: 'FKGrotesk',
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (isSelected)
                          const Icon(Icons.check_circle, color: Colors.yellow, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackIcon(SwapToken token) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          token.symbol.substring(0, token.symbol.length >= 2 ? 2 : 1),
          style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
