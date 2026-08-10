import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solfare/core/util/app_log.dart';
import 'package:solfare/features/market/data/datasource/jupiter_token_datasource.dart';
import 'package:solfare/features/market/domain/entities/market_token.dart';
import 'package:solfare/features/market/domain/entities/market_window.dart';
import 'package:solfare/features/market/presentation/market_format.dart';
import 'package:solfare/features/market/presentation/widgets/market_token_icon.dart';

/// Search across every mint Jupiter indexes, not just the page on screen.
class MarketSearchSheet extends StatefulWidget {
  final void Function(MarketToken token) onSelected;
  final JupiterTokenDataSource? source;

  const MarketSearchSheet({super.key, required this.onSelected, this.source});

  @override
  State<MarketSearchSheet> createState() => _MarketSearchSheetState();
}

class _MarketSearchSheetState extends State<MarketSearchSheet> {
  static const _debounce = Duration(milliseconds: 300);

  late final JupiterTokenDataSource _source = widget.source ?? JupiterTokenDataSource();
  final TextEditingController _controller = TextEditingController();

  Timer? _timer;
  List<MarketToken> _results = const [];
  bool _searching = false;
  String? _error;

  // Bumped per query so a slow response for an earlier keystroke cannot land on
  // top of a later one.
  int _queryId = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    setState(() => _searching = true);
    _timer = Timer(_debounce, () => _run(query));
  }

  Future<void> _run(String query) async {
    final id = ++_queryId;
    try {
      final results = await _source.search(query);
      if (!mounted || id != _queryId) return;
      setState(() {
        _results = results;
        _searching = false;
        _error = null;
      });
    } catch (e) {
      debugLog('[Market] search failed: $e');
      if (!mounted || id != _queryId) return;
      setState(() {
        _searching = false;
        _error = 'Search is not answering right now.';
      });
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _onChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
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
            _searchField(),
            const SizedBox(height: 8),
            Expanded(child: _results.isEmpty ? _placeholder() : _list()),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return Padding(
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
                controller: _controller,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'FKGrotesk',
                ),
                decoration: InputDecoration(
                  hintText: 'Search or paste a mint address',
                  hintStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontFamily: 'FKGrotesk',
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                onChanged: _onChanged,
              ),
            ),
            GestureDetector(
              onTap: _paste,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Paste',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    final text = _error ??
        (_searching
            ? 'Searching…'
            : _controller.text.trim().isEmpty
                ? 'Search by name, ticker or mint address.'
                : 'Nothing matched that.');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'FKGrotesk'),
        ),
      ),
    );
  }

  Widget _list() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final token = _results[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
            widget.onSelected(token);
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                MarketTokenIcon(token: token, size: 36),
                const SizedBox(width: 12),
                Expanded(child: _identity(token)),
                _priceColumn(token),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _identity(MarketToken token) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                token.symbol.isNotEmpty ? token.symbol : MarketFormat.shortMint(token.id),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (token.isVerified) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, color: Color(0xFF7BD64B), size: 12),
            ],
          ],
        ),
        const SizedBox(height: 2),
        // Search turns up many tokens wearing the same ticker, so the row has
        // to say which one this is.
        Text(
          '${token.name} · ${MarketFormat.shortMint(token.id)}',
          style: TextStyle(color: Colors.grey[600], fontSize: 11, fontFamily: 'FKGrotesk'),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _priceColumn(MarketToken token) {
    final change = token.priceChange(MarketWindow.h24);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          MarketFormat.price(token.currentPrice),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'FKGroteskSemiMono',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          MarketFormat.percent(change),
          style: TextStyle(
            color: change >= 0 ? const Color(0xFF7BD64B) : const Color(0xFFFF5252),
            fontSize: 11,
            fontFamily: 'FKGroteskSemiMono',
          ),
        ),
      ],
    );
  }
}
