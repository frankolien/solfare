import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:solfare/features/wallet/domain/entities/transactions.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:solfare/features/wallet/presentation/widgets/transaction_detail_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class TransactionHistoryScreen extends StatefulWidget {
  final String address;

  const TransactionHistoryScreen({super.key, required this.address});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  bool _isRefreshing = false;
  List<Transaction> _cachedTransactions = [];

  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(FetchTransactionsEvent(widget.address));
  }

  void _onRefresh() {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    context.read<WalletBloc>().add(FetchTransactionsEvent(widget.address));
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _isRefreshing = false);
    });
  }

  Map<String, List<Transaction>> _groupByDate(List<Transaction> transactions) {
    final now = DateTime.now();
    final Map<String, List<Transaction>> grouped = {};

    for (final tx in transactions) {
      final diff = now.difference(tx.timestamp).inDays;
      String label;

      if (diff == 0) {
        label = 'TODAY';
      } else if (diff < 7) {
        label = _weekdayName(tx.timestamp.weekday).toUpperCase();
      } else {
        label = '${tx.timestamp.day.toString().padLeft(2, '0')} ${_monthName(tx.timestamp.month).toUpperCase()}';
      }

      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(tx);
    }

    return grouped;
  }

  String _weekdayName(int weekday) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[weekday - 1];
  }

  String _monthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }

  bool _isSent(Transaction tx) {
    return tx.sender.toLowerCase() == widget.address.toLowerCase();
  }

  String _truncateAddress(String address) {
    if (address.length <= 8) return address;
    return '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Activity',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'FKGrotesk',
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        centerTitle: true,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification &&
              notification.metrics.pixels < -80 &&
              !_isRefreshing) {
            _onRefresh();
          }
          return false;
        },
        child: BlocBuilder<WalletBloc, WalletState>(
          builder: (context, state) {
            // Cache transactions when they arrive
            if (state is TransactionsFetched) {
              _cachedTransactions = state.transactions;
            }

            // First load — no cached data yet
            if (state is WalletLoading && _cachedTransactions.isEmpty) {
              return _buildLoadingState();
            }

            // Show cached transactions (even during refresh)
            if (_cachedTransactions.isNotEmpty) {
              return _buildTransactionList(_cachedTransactions);
            }

            if (state is TransactionsFetched && state.transactions.isEmpty) {
              return _buildEmptyState();
            }

            if (state is WalletError && _cachedTransactions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    state.message,
                    style: TextStyle(color: Colors.grey[400], fontSize: 12, fontFamily: 'FKGrotesk'),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // Shimmer loading skeleton
  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _buildShimmerSection('', 1),
        _buildShimmerSection('', 5),
        _buildShimmerSection('', 2),
      ],
    );
  }

  Widget _buildShimmerSection(String label, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 16),
          child: Container(
            width: 70,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.grey[850] ?? Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        ...List.generate(count, (_) => _buildShimmerRow()),
      ],
    );
  }

  Widget _buildShimmerRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 140,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[850] ?? Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, color: Colors.grey[700], size: 40),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions) {
    final grouped = _groupByDate(transactions);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lottie refresh indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isRefreshing ? 50 : 0,
            child: _isRefreshing
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: Lottie.asset(
                        'assets/assets/lottie/loading_indicator.json',
                        repeat: true,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          ...grouped.entries.map((entry) {
            final label = entry.key;
            final txs = entry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 12),
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...txs.map((tx) => _buildTransactionRow(tx)),
          ],
        );
          }),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(Transaction tx) {
    final sent = _isSent(tx);
    final amountInSol = tx.amount / 1000000000;
    final sign = sent ? '-' : '+';
    final color = sent ? Colors.white : const Color(0xFF4CAF50);
    final otherAddress = sent ? tx.receiver : tx.sender;

    return GestureDetector(
      onTap: () => _showTransactionDetail(tx),
      onLongPress: () => _showContextMenu(tx),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // SOL logo
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF1C1F26),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.network(
                  "https://assets.coingecko.com/coins/images/4128/large/solana.png",
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.currency_bitcoin,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sent ? 'Sent' : 'Received',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sent ? 'To' : 'From'}:  ${_truncateAddress(otherAddress)}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                      fontFamily: 'FKGrotesk',
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$sign${amountInSol.toStringAsFixed(amountInSol == amountInSol.roundToDouble() ? 0 : 2)} SOL',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontFamily: 'FKGroteskSemiMono',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetail(Transaction tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TransactionDetailSheet(
        tx: tx,
        walletAddress: widget.address,
      ),
    );
  }

  void _showContextMenu(Transaction tx) {
    HapticFeedback.mediumImpact();
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(20, 200, overlay.size.width - 20, 0),
      color: const Color(0xFF1C1F26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          onTap: () async {
            final url = 'https://explorer.solana.com/tx/${tx.signature}?cluster=devnet';
            try {
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            } catch (_) {
              if (mounted) {
                Clipboard.setData(ClipboardData(text: url));
              }
            }
          },
          child: const Text(
            'View on explorer',
            style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk'),
          ),
        ),
        PopupMenuItem(
          onTap: () {
            Clipboard.setData(ClipboardData(text: tx.signature));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transaction ID copied'),
                backgroundColor: Color(0xFF1C1F26),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Text(
            'Copy transaction ID',
            style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk'),
          ),
        ),
        PopupMenuItem(
          onTap: () {
            SharePlus.instance.share(ShareParams(text: 'https://explorer.solana.com/tx/${tx.signature}?cluster=devnet'));
          },
          child: const Text(
            'Share',
            style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk'),
          ),
        ),
      ],
    );
  }
}
