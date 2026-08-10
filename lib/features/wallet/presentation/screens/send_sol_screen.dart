import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/core/solana/pay/pay_resolver.dart';
import 'package:solfare/core/solana/tx_outcome.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:solfare/features/wallet/data/datasource/contacts_local_datasource.dart';
import 'package:solfare/features/wallet/domain/entities/spl_token.dart';
import 'package:solfare/features/wallet/presentation/screens/qr_scanner_screen.dart';
import 'package:solfare/features/wallet/presentation/widgets/confirm_send_sheet.dart';
import 'package:solfare/features/wallet/presentation/widgets/solana_pay_sheet.dart';
import 'package:solfare/features/wallet/presentation/widgets/send_status_sheet.dart';

enum _SendStage { recipient, amount }

class SendSolScreen extends StatefulWidget {
  final String senderAddress;
  final double balanceInSol;
  final double solPriceUsd;

  /// Null sends native SOL. Set to send that SPL token instead — the screen
  /// is the same, only the asset it moves changes.
  final SplToken? token;

  const SendSolScreen({
    super.key,
    required this.senderAddress,
    required this.balanceInSol,
    required this.solPriceUsd,
    this.token,
  });

  @override
  State<SendSolScreen> createState() => _SendSolScreenState();
}

class _SendSolScreenState extends State<SendSolScreen> {
  _SendStage _stage = _SendStage.recipient;

  // The screen reads these instead of the SOL-specific fields, so the same
  // flow works for a token without branching through the whole widget tree.
  SplToken? get _token => widget.token;

  String get _symbol {
    final token = _token;
    if (token == null) return 'SOL';
    if (token.symbol.isNotEmpty) return token.symbol;
    // A mint with no metadata has no ticker. Showing nothing beside the
    // amount reads as broken, so fall back to the mint itself.
    final mint = token.mint;
    return mint.length <= 8
        ? mint
        : '${mint.substring(0, 4)}…${mint.substring(mint.length - 4)}';
  }
  double get _balance => _token?.balance ?? widget.balanceInSol;
  double get _priceUsd => _token?.priceUsd ?? widget.solPriceUsd;

  final TextEditingController _addressController = TextEditingController();

  // WalletBloc is app-wide, so this screen sees states belonging to balance
  // refreshes, price ticks and history fetches. Only a send this screen
  // started may drive its status sheet.
  bool _sendInFlight = false;
  String _amount = '0';
  String _recipientName = '';
  final ContactsLocalDataSource _contactsDS = ContactsLocalDataSource();
  List<Contact> _recents = [];
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final recents = await _contactsDS.getRecents();
    final contacts = await _contactsDS.getContacts();
    if (mounted) {
      setState(() {
        _recents = recents;
        _contacts = contacts;
      });
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  String get _recipientAddress => _addressController.text.trim();

  double get _amountInSol {
    final parsed = double.tryParse(_amount);
    return parsed ?? 0.0;
  }

  double get _amountInUsd => _amountInSol * _priceUsd;

  String _truncateAddress(String address) {
    if (address.length <= 8) return address;
    return '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _onPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;

    // A solana: URL is a normal thing to be sent over chat, and pasting one
    // used to drop it into the address field verbatim — where it passed the
    // length check and then died inside fromBase58 with a raw exception.
    // Same handling as the scanner: it is the same payload either way.
    if (PayResolver.parse(text) != null) {
      _handleScanned(text);
      return;
    }

    _addressController.text = text;
    setState(() {});
  }

  void _selectRecipient({String? name, String? address}) {
    final addr = address ?? _recipientAddress;
    if (addr.length < 32) return;
    final contactName = name ?? _truncateAddress(addr);
    _contactsDS.addRecent(Contact(name: contactName, address: addr));
    setState(() {
      _addressController.text = addr;
      _recipientName = contactName;
      _stage = _SendStage.amount;
    });
  }

  void _onDigit(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_amount == '0' && digit != '.') {
        _amount = digit;
      } else if (digit == '.' && _amount.contains('.')) {
        return;
      } else {
        // Limit decimals to 9 (lamport precision)
        if (_amount.contains('.')) {
          final decimals = _amount.split('.')[1];
          if (decimals.length >= 9) return;
        }
        _amount += digit;
      }
    });
  }

  void _onDelete() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_amount.length <= 1) {
        _amount = '0';
      } else {
        _amount = _amount.substring(0, _amount.length - 1);
      }
    });
  }

  void _setPercentage(double pct) {
    HapticFeedback.lightImpact();
    final value = _balance * pct;
    setState(() {
      _amount = value.toStringAsFixed(9).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      if (_amount.isEmpty) _amount = '0';
    });
  }

  void _showConfirmSheet() {
    if (_amountInSol <= 0 || _amountInSol > _balance) return;

    // Kick the simulation off as the sheet opens rather than before it, so
    // the sheet is on screen for the whole wait instead of after it.
    final token = _token;
    context.read<WalletBloc>().add(token == null
        ? PreviewSendEvent(
            recipientAddress: _recipientAddress,
            amountInSol: _amountInSol,
          )
        : PreviewTokenSendEvent(
            mint: token.mint,
            recipientAddress: _recipientAddress,
            amount: _amountInSol,
          ));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (context) => ConfirmSendSheet(
        recipientAddress: _recipientAddress,
        recipientName: _recipientName,
        amountInSol: _amountInSol,
        amountInUsd: _amountInUsd,
        symbol: _symbol,
        iconUrl: _token?.imageUrl,
        onConfirm: () {
          Navigator.of(context).pop();
          _executeSend();
        },
      ),
    );
  }

  /// A scanned code is either a Solana Pay request or a plain address.
  ///
  /// A pay request goes to the pay sheet rather than being unpacked into this
  /// screen's fields. This screen sends one asset — whichever it was opened
  /// for — and it used to read only `recipient` and `amount` off the request,
  /// dropping `spl-token` entirely: a 25 USDC merchant code scanned here
  /// prefilled "25" and sent 25 SOL. It also dropped the reference keys the
  /// merchant needs to reconcile the payment, so even the native-SOL case was
  /// only accidentally right.
  void _handleScanned(String scanned) {
    if (PayResolver.parse(scanned) == null) {
      _selectRecipient(address: scanned);
      return;
    }

    context.read<WalletBloc>().add(ResolvePayEvent(scanned));
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SolanaPaySheet(),
    );
  }

  void _executeSend() {
    final token = _token;
    _sendInFlight = true;
    context.read<WalletBloc>().add(token == null
        ? SendSolEvent(
            recipientAddress: _recipientAddress,
            amountInSol: _amountInSol,
          )
        : SendTokenEvent(
            mint: token.mint,
            symbol: token.symbol,
            recipientAddress: _recipientAddress,
            amount: _amountInSol,
          ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WalletBloc, WalletState>(
      listener: (context, state) {
        // WalletBloc is app-wide and this screen shares it with the balance
        // and history fetches — which _onSendSol itself kicks off the moment
        // a send confirms. Without this gate a 429 on that follow-up fetch
        // replaced the success sheet with "Failed", telling the user their
        // money did not move when it had.
        if (!_sendInFlight) return;

        if (state is SendingSol) {
          // Only the first phase opens the sheet; the rest update it in place
          // via the BlocBuilder inside SendStatusSheet.
          if (state.phase == TxPhase.preparing) _showStatusSheet('sending');
        } else if (state is SolSent) {
          _sendInFlight = false;
          _dismissStatusSheet();
          _showStatusSheet('success', signature: state.signature);
        } else if (state is SolSendFailed) {
          _sendInFlight = false;
          _dismissStatusSheet();
          _showStatusSheet('error', error: state.message, signature: state.signature);
        } else if (state is WalletError) {
          _sendInFlight = false;
          _dismissStatusSheet();
          _showStatusSheet('error', error: state.message);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (_stage == _SendStage.amount) {
                setState(() => _stage = _SendStage.recipient);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: _stage == _SendStage.recipient
              ? const Text(
                  'Select recipient',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Send to',
                      style: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(_recipientName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontFamily: 'FKGrotesk',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _recipientName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
          centerTitle: true,
          actions: [
            if (_stage == _SendStage.recipient)
              IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
                onPressed: () async {
                  final address = await Navigator.of(context).push<String>(
                    MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                  );
                  if (address != null && mounted) {
                    _handleScanned(address);
                  }
                },
              ),
          ],
        ),
        body: SafeArea(
          child: _stage == _SendStage.recipient
              ? _buildRecipientStage()
              : _buildAmountStage(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STAGE 1: Select recipient
  // ─────────────────────────────────────────────
  Widget _buildRecipientStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Address input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'FKGrotesk',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Select or paste address',
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontFamily: 'FKGrotesk',
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _selectRecipient(),
                  ),
                ),
                GestureDetector(
                  onTap: _onPaste,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Paste',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Contact lists
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recents
                if (_recents.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'RECENT',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._recents.map((c) => _buildContactRow(c)),
                ],

                // Address book
                if (_contacts.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'ADDRESS BOOK',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._contacts.map((c) => _buildContactRow(c)),
                ],

                if (_recipientAddress.length >= 32 && _recents.isEmpty && _contacts.isEmpty) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () => _selectRecipient(),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontFamily: 'FKGrotesk',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactRow(Contact contact) {
    return GestureDetector(
      onTap: () => _selectRecipient(name: contact.name, address: contact.address),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  contact.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.truncatedAddress,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontFamily: 'FKGrotesk',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // STAGE 2: Enter amount
  // ─────────────────────────────────────────────
  Widget _buildAmountStage() {
    final isValidAmount = _amountInSol > 0 && _amountInSol <= _balance;

    return Column(
      children: [
        const Spacer(flex: 2),

        // Amount display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _amount,
                style: TextStyle(
                  color: _amountInSol > _balance ? Colors.red : Colors.white,
                  fontSize: 35,
                  fontFamily: 'FKGroteskSemiMono',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _symbol,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // USD value
        if (_amountInSol > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '\$${_amountInUsd.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                fontFamily: 'FKGroteskSemiMono',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),

        const Spacer(flex: 3),

        // Balance + Priority row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1C1F26),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.network(
                          "https://assets.coingecko.com/coins/images/4128/large/solana.png",
                          width: 16,
                          height: 16,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_balance.toStringAsFixed(3)} $_symbol',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'FKGroteskSemiMono',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.grey[400], size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Public',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down, color: Colors.grey[400], size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const Divider(color: Colors.white10, height: 1, indent: 24, endIndent: 24),
        const SizedBox(height: 12),

        // Percentage buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _buildPctButton('25%', 0.25),
              const SizedBox(width: 8),
              _buildPctButton('50%', 0.50),
              const SizedBox(width: 8),
              _buildPctButton('75%', 0.75),
              const SizedBox(width: 8),
              _buildPctButton('Max', 1.0),
            ],
          ),
        ),

        const SizedBox(height: 12),
        const Divider(color: Colors.white10, height: 1, indent: 24, endIndent: 24),
        const SizedBox(height: 8),

        // Keypad
        _buildKeypad(),

        const SizedBox(height: 18),

        // Continue button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isValidAmount ? Colors.yellow : const Color(0xFF2A2D35),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: isValidAmount ? _showConfirmSheet : null,
              child: Text(
                'Continue',
                style: TextStyle(
                  color: isValidAmount ? Colors.black : Colors.grey[600],
                  fontSize: 14,
                  fontFamily: 'FKGrotesk',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPctButton(String label, double pct) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _setPercentage(pct),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'FKGrotesk',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          for (int row = 0; row < 3; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int col = 0; col < 3; col++)
                    _buildKey('${row * 3 + col + 1}'),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKey('.'),
              _buildKey('0'),
              GestureDetector(
                onTap: _onDelete,
                child: const SizedBox(
                  width: 70,
                  height: 50,
                  child: Center(
                    child: Icon(Icons.backspace_outlined, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String digit) {
    return GestureDetector(
      onTap: () => _onDigit(digit),
      child: SizedBox(
        width: 70,
        height: 50,
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'FKGroteskSemiMono',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  // The route the status sheet is sitting on, so it can be dismissed by
  // identity. The old code popped by predicate — one of them
  // (`route.isFirst == false && route.settings.name == null`) matched the
  // sheet itself and so popped nothing, leaving the spinner alive underneath
  // the success sheet; the others popped whatever happened to be on top.
  ModalRoute<void>? _statusRoute;

  void _dismissStatusSheet() {
    final route = _statusRoute;
    _statusRoute = null;
    if (route != null && route.isActive) {
      Navigator.of(context).removeRoute(route);
    }
  }

  void _showStatusSheet(String status, {String? signature, String? error}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: status != 'sending',
      enableDrag: status != 'sending',
      isScrollControlled: true,
      routeSettings: RouteSettings(name: 'send-status/$status'),
      builder: (sheetContext) {
        _statusRoute = ModalRoute.of(sheetContext) as ModalRoute<void>?;
        return _statusSheet(sheetContext, status, signature, error);
      },
    ).whenComplete(() => _statusRoute = null);
  }

  Widget _statusSheet(
    BuildContext sheetContext,
    String status,
    String? signature,
    String? error,
  ) {
    return SendStatusSheet(
        status: status,
        signature: signature,
        error: error,
        onClose: () {
          Navigator.of(sheetContext).pop();
          context.go(AppRoutes.homepage);
        },
        onSaveAddress: () {
          Navigator.of(sheetContext).pop();
          _showSaveContactSheet();
        },
    );
  }

  void _showSaveContactSheet() {
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF141518),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                    child: Row(
                      children: [
                        const Spacer(),
                        const Text(
                          'New contact',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'FKGrotesk',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // NAME label
                        Text(
                          'NAME',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                            fontFamily: 'FKGrotesk',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Name input
                        TextField(
                          controller: nameController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'FKGrotesk',
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.yellow),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          autofocus: true,
                          onChanged: (_) => setSheetState(() {}),
                        ),

                        const SizedBox(height: 20),

                        // ADDRESS label
                        Text(
                          'ADDRESS',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                            fontFamily: 'FKGrotesk',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Address display
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  nameController.text.isNotEmpty
                                      ? _getInitials(nameController.text)
                                      : '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontFamily: 'FKGrotesk',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _truncateAddress(_recipientAddress),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontFamily: 'FKGrotesk',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: nameController.text.trim().isNotEmpty
                                  ? Colors.yellow
                                  : const Color(0xFF2A2D35),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: nameController.text.trim().isNotEmpty
                                ? () async {
                                    await _contactsDS.saveContact(Contact(
                                      name: nameController.text.trim(),
                                      address: _recipientAddress,
                                    ));
                                    await _loadContacts();
                                    if (mounted) {
                                      Navigator.of(sheetContext).pop();
                                      context.go(AppRoutes.homepage);
                                    }
                                  }
                                : null,
                            child: Text(
                              'Save',
                              style: TextStyle(
                                color: nameController.text.trim().isNotEmpty
                                    ? Colors.black
                                    : Colors.grey[600],
                                fontSize: 14,
                                fontFamily: 'FKGrotesk',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
