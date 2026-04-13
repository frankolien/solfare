import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lottie/lottie.dart';
import 'package:solfare/features/swap/domain/entities/swap_token.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_bloc.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_event.dart';
import 'package:solfare/features/swap/presentation/bloc/swap_state.dart';
import 'package:solfare/core/constant/network.dart';
import 'package:solfare/features/swap/presentation/widgets/token_selector_sheet.dart';

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final _inputController = TextEditingController();
  String? _walletAddress;
  int _selectedTab = 0; // 0 = Swap, 1 = Limit
  String _expiry = 'Never';

  @override
  void initState() {
    super.initState();
    context.read<SwapBloc>().add(const LoadTokenListEvent());
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    final address = await const FlutterSecureStorage().read(key: 'wallet_address');
    if (mounted) setState(() => _walletAddress = address);
  }

  void _showTokenSelector(BuildContext context, List<SwapToken> tokens, SwapToken current, bool isInput) async {
    final selected = await showModalBottomSheet<SwapToken>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TokenSelectorSheet(tokens: tokens, selectedToken: current),
    );
    if (selected != null && mounted) {
      if (isInput) {
        context.read<SwapBloc>().add(SelectInputTokenEvent(selected));
      } else {
        context.read<SwapBloc>().add(SelectOutputTokenEvent(selected));
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0b12),
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<SwapBloc, SwapState>(
          listener: (context, state) {
            if (state is SwapSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Swap successful!'), backgroundColor: Colors.green),
              );
              context.read<SwapBloc>().add(const LoadTokenListEvent());
            } else if (state is SwapError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.red),
              );
              context.read<SwapBloc>().add(const LoadTokenListEvent());
            }
          },
          builder: (context, state) {
            if (state is SwapLoading) {
              return const Center(child: CircularProgressIndicator(color: Colors.yellow, strokeWidth: 2));
            }
            if (state is SwapExecuting) {
              return _buildExecutingState();
            }
            if (state is SwapReady) {
              return _buildSwapUI(context, state);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildExecutingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80, height: 80,
            child: Lottie.asset('assets/assets/lottie/loading_indicator.json', repeat: true),
          ),
          const SizedBox(height: 16),
          const Text('Executing swap...', style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSwapUI(BuildContext context, SwapReady state) {
    return Column(
      children: [
        // Header — MW + Swap/Limit toggle
        _buildHeader(),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _selectedTab == 0
                ? _buildSwapTab(context, state)
                : _buildLimitTab(context, state),
          ),
        ),

        // Insufficient SOL warning + Swap button pinned at bottom
        if (_selectedTab == 0)
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning banner
                if (state.outputAmount != null)
                  _buildWarningBanner(state),
                const SizedBox(height: 10),
                _buildSwapButton(context, state),
                
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle),
            child: const Center(child: Text('MW', style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 50),

          // Swap / Limit toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildTabButton('Swap', 0),
                _buildTabButton('Limit', 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[800] : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[500],
            fontSize: 12,
            fontFamily: 'FKGrotesk',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─── SWAP TAB ───

  Widget _buildSwapTab(BuildContext context, SwapReady state) {
    return Column(
      children: [
        const SizedBox(height: 20),

        // SELL section
        _buildSellSection(context, state),

        // Divider with flip button
        _buildFlipDivider(context),

        // BUY section
        _buildBuySection(context, state),

        // Rate + Slippage (only when quote exists)
        if (state.rate != null) ...[
          const SizedBox(height: 16),
          Divider(color: Colors.grey[800], height: 1),
          const SizedBox(height: 12),
          _buildRateRow(
            'Rate',
            '1 ${state.inputToken.symbol} = ${state.rate!.toStringAsFixed(3)} ${state.outputToken.symbol}',
          ),
          const SizedBox(height: 8),
          _buildSlippageRow(),
        ],

        if (state.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(state.error!, style: const TextStyle(color: Color(0xFFFF5252), fontSize: 10, fontFamily: 'FKGrotesk')),
          ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRateRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk')),
        const SizedBox(width: 4),
        Icon(Icons.info_outline, color: Colors.grey[600], size: 12),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSlippageRow() {
    return Row(
      children: [
        Text('Slippage tolerance', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk')),
        const SizedBox(width: 4),
        Icon(Icons.info_outline, color: Colors.grey[600], size: 12),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('0.5% (Auto)', style: TextStyle(color: Colors.grey[400], fontSize: 10, fontFamily: 'FKGroteskSemiMono')),
              const SizedBox(width: 4),
              Icon(Icons.unfold_more, color: Colors.grey[500], size: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSellSection(BuildContext context, SwapReady state) {
    return Column(
      children: [
        // SELL label + Max
        Row(
          children: [
            Text('SELL', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500, letterSpacing: 1)),
            const Spacer(),
            Text('Max: 0', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk')),
          ],
        ),
        const SizedBox(height: 12),

        // Token selector + amount
        Row(
          children: [
            _buildTokenChip(state.inputToken, () => _showTokenSelector(context, state.tokens, state.inputToken, true)),
            const Spacer(),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _inputController,
                style: TextStyle(color: Colors.grey[500], fontSize: 28, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w400),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.grey[700], fontSize: 28, fontFamily: 'FKGroteskSemiMono'),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                onChanged: (val) {
                  context.read<SwapBloc>().add(UpdateInputAmountEvent(val));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFlipDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Divider(color: Colors.grey[800], height: 1),
          GestureDetector(
            onTap: () {
              context.read<SwapBloc>().add(const FlipTokensEvent());
              _inputController.clear();
            },
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1F26),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[800]!, width: 1),
              ),
              child: const Icon(Icons.swap_vert, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuySection(BuildContext context, SwapReady state) {
    return Column(
      children: [
        // BUY label + Balance
        Row(
          children: [
            Text('BUY', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500, letterSpacing: 1)),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, color: Colors.grey[600], size: 12),
            const Spacer(),
            Text('Balance: 0', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk')),
          ],
        ),
        const SizedBox(height: 12),

        // Token selector + output amount
        Row(
          children: [
            _buildTokenChip(state.outputToken, () => _showTokenSelector(context, state.tokens, state.outputToken, false)),
            const Spacer(),
            state.isLoadingQuote
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey[500]))
                : Text(
                    state.outputAmount ?? '0',
                    style: TextStyle(
                      color: state.outputAmount != null ? Colors.white : Colors.grey[700],
                      fontSize: 28,
                      fontFamily: 'FKGroteskSemiMono',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
          ],
        ),
      ],
    );
  }

  Widget _buildWarningBanner(SwapReady state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2a1a1a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(color: const Color(0xFFFF5252), borderRadius: BorderRadius.circular(4)),
            child: const Icon(Icons.close, color: Colors.white, size: 12),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insufficient ${state.inputToken.symbol}',
                  style: const TextStyle(color: Color(0xFFFF5252), fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Make sure you have more than 0.005 SOL in your wallet to cover network fees.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 10, fontFamily: 'FKGrotesk', height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapButton(BuildContext context, SwapReady state) {
    // TODO: check actual wallet balance for inputToken to determine sufficiency
    final hasQuote = state.outputAmount != null;
    final hasSufficientBalance = false; // Will be true when user has enough balance
    final isMainnet = NetworkConstants.current == SolanaNetwork.mainnet;
    final enabled = hasQuote && hasSufficientBalance && isMainnet && _walletAddress != null;

    void onTap() {
      if (enabled) {
        context.read<SwapBloc>().add(ExecuteSwapEvent(_walletAddress!));
      }
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? Colors.yellow : Colors.grey[850] ?? Colors.grey[800],
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        onPressed: enabled ? onTap : null,
        child: Text(
          !isMainnet ? 'Swap available on Mainnet' : 'Swap',
          style: TextStyle(
            color: enabled ? Colors.black : Colors.grey[600],
            fontSize: 13,
            fontFamily: 'FKGrotesk',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─── LIMIT TAB ───

  Widget _buildLimitTab(BuildContext context, SwapReady state) {
    return Column(
      children: [
        const SizedBox(height: 20),

        // SELL section (same as swap)
        _buildSellSection(context, state),
        _buildFlipDivider(context),
        _buildBuySection(context, state),

        const SizedBox(height: 20),

        // SELL [TOKEN] AT PRICE
        Row(
          children: [
            Text('SELL ${state.inputToken.symbol} AT PRICE', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500, letterSpacing: 0.5)),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, color: Colors.grey[600], size: 12),
            const Spacer(),
            Text(
              state.rate != null ? 'Market: ${state.rate!.toStringAsFixed(3)}' : 'Market: --',
              style: TextStyle(color: Colors.grey[400], fontSize: 10, fontFamily: 'FKGroteskSemiMono'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Price input row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              ClipOval(
                child: state.outputToken.logoUrl != null
                    ? Image.network(state.outputToken.logoUrl!, width: 20, height: 20, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _tokenFallbackSmall(state.outputToken))
                    : _tokenFallbackSmall(state.outputToken),
              ),
              const SizedBox(width: 8),
              Text(state.outputToken.symbol, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(
                state.rate != null ? state.rate!.toStringAsFixed(3) : '--',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGroteskSemiMono', fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Expiry
        Row(
          children: [
            Text('Expiry', style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Icon(Icons.info_outline, color: Colors.grey[600], size: 12),
            const Spacer(),
            PopupMenuButton<String>(
              onSelected: (val) => setState(() => _expiry = val),
              color: const Color(0xFF1C1F26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (_) => ['15 minutes', '1 hour', '1 day', '3 days', '7 days', '30 days', '90 days', 'Never']
                  .map((e) => PopupMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk')),
                      ))
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_expiry, style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'FKGrotesk')),
                    const SizedBox(width: 4),
                    Icon(Icons.unfold_more, color: Colors.grey[500], size: 14),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Place order button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[850] ?? Colors.grey[800],
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            onPressed: null,
            child: Text('Place order', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
          ),
        ),

        const SizedBox(height: 24),

        // Open orders / Order history tabs
        Row(
          children: [
            Column(
              children: [
                const Text('Open orders', style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Container(width: 70, height: 2, color: Colors.yellow),
              ],
            ),
            const SizedBox(width: 20),
            Text('Order history', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w400)),
          ],
        ),

        const Divider(color: Colors.white10, height: 1),

        const SizedBox(height: 40),

        Text('No open orders', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk')),

        const SizedBox(height: 60),
      ],
    );
  }

  // ─── SHARED WIDGETS ───

  Widget _buildTokenChip(SwapToken token, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: token.logoUrl != null
                  ? Image.network(token.logoUrl!, width: 24, height: 24, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _tokenFallback(token))
                  : _tokenFallback(token),
            ),
            const SizedBox(width: 8),
            Text(token.symbol, style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  Widget _tokenFallback(SwapToken token) {
    return Container(
      width: 24, height: 24,
      decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle),
      child: Center(child: Text(token.symbol.substring(0, 1), style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.bold))),
    );
  }

  Widget _tokenFallbackSmall(SwapToken token) {
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle),
      child: Center(child: Text(token.symbol.substring(0, 1), style: const TextStyle(color: Colors.white, fontSize: 8, fontFamily: 'FKGrotesk', fontWeight: FontWeight.bold))),
    );
  }
}
