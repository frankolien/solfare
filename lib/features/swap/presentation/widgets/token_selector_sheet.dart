import 'package:flutter/material.dart';
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
  List<SwapToken> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.tokens;
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.tokens;
      } else {
        _filtered = widget.tokens
            .where((t) =>
                t.symbol.toLowerCase().contains(query.toLowerCase()) ||
                t.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
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
          // Drag handle
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

          // Title
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

          // Search bar
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

          // Token list
          Expanded(
            child: ListView.builder(
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
                        // Logo
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

                        // Name + symbol
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
