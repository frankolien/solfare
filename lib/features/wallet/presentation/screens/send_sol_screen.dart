import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:solfare/core/router/app_router.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:solfare/features/wallet/presentation/bloc/wallet_state.dart';
import 'package:solfare/features/wallet/data/datasource/contacts_local_datasource.dart';

enum _SendStage { recipient, amount }

class SendSolScreen extends StatefulWidget {
  final String senderAddress;
  final double balanceInSol;
  final double solPriceUsd;

  const SendSolScreen({
    super.key,
    required this.senderAddress,
    required this.balanceInSol,
    required this.solPriceUsd,
  });

  @override
  State<SendSolScreen> createState() => _SendSolScreenState();
}

class _SendSolScreenState extends State<SendSolScreen> {
  _SendStage _stage = _SendStage.recipient;
  final TextEditingController _addressController = TextEditingController();
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

  double get _amountInUsd => _amountInSol * widget.solPriceUsd;

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

  void _onPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _addressController.text = data!.text!.trim();
      setState(() {});
    }
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
    final value = widget.balanceInSol * pct;
    setState(() {
      _amount = value.toStringAsFixed(9).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      if (_amount.isEmpty) _amount = '0';
    });
  }

  void _showConfirmSheet() {
    if (_amountInSol <= 0 || _amountInSol > widget.balanceInSol) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      builder: (context) => _ConfirmSendSheet(
        recipientAddress: _recipientAddress,
        recipientName: _recipientName,
        amountInSol: _amountInSol,
        amountInUsd: _amountInUsd,
        onConfirm: () {
          Navigator.of(context).pop();
          _executeSend();
        },
      ),
    );
  }

  void _executeSend() {
    context.read<WalletBloc>().add(SendSolEvent(
          recipientAddress: _recipientAddress,
          amountInSol: _amountInSol,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WalletBloc, WalletState>(
      listener: (context, state) {
        if (state is SendingSol) {
          _showStatusSheet('sending');
        } else if (state is SolSent) {
          Navigator.of(context).popUntil((route) => route.isFirst == false && route.settings.name == null);
          _showStatusSheet('success', signature: state.signature);
        } else if (state is WalletError) {
          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
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

                // Show continue button if typed address is valid
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
    final isValidAmount = _amountInSol > 0 && _amountInSol <= widget.balanceInSol;

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
                  color: _amountInSol > widget.balanceInSol ? Colors.red : Colors.white,
                  fontSize: 35,
                  fontFamily: 'FKGroteskSemiMono',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'SOL',
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
                      '${widget.balanceInSol.toStringAsFixed(3)} SOL',
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

  void _showStatusSheet(String status, {String? signature, String? error}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: status != 'sending',
      enableDrag: status != 'sending',
      isScrollControlled: true,
      builder: (sheetContext) => _StatusSheet(
        status: status,
        signature: signature,
        error: error,
        recipientAddress: _recipientAddress,
        onClose: () {
          Navigator.of(sheetContext).pop();
          context.go(AppRoutes.homepage);
        },
        onSaveAddress: () {
          Navigator.of(sheetContext).pop();
          _showSaveContactSheet();
        },
      ),
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

                        // Save button
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

// ─────────────────────────────────────────────
// Confirm Send Bottom Sheet
// ─────────────────────────────────────────────
class _ConfirmSendSheet extends StatefulWidget {
  final String recipientAddress;
  final String recipientName;
  final double amountInSol;
  final double amountInUsd;
  final VoidCallback onConfirm;

  const _ConfirmSendSheet({
    required this.recipientAddress,
    required this.recipientName,
    required this.amountInSol,
    required this.amountInUsd,
    required this.onConfirm,
  });

  @override
  State<_ConfirmSendSheet> createState() => _ConfirmSendSheetState();
}

class _ConfirmSendSheetState extends State<_ConfirmSendSheet> {
  double _slidePosition = 0;
  static const double _slideThreshold = 0.7;

  String _truncate(String s) {
    if (s.length <= 8) return s;
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
       
   
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(50, 16, 8, 0),
            child: Row(
              children: [
                const Spacer(),
                const Text(
                  'Send',
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // SOL icon
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.network(
                "https://assets.coingecko.com/coins/images/4128/large/solana.png",
                width: 56,
                height: 56,
                //fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Amount
          Text(
            '${widget.amountInSol} SOL',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontFamily: 'FKGroteskSemiMono',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${widget.amountInUsd.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
              fontFamily: 'FKGroteskSemiMono',
            ),
          ),

          const SizedBox(height: 40),

          // To row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'To',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'FKGrotesk',
                  ),
                ),
                const Spacer(),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(widget.recipientName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.recipientName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'FKGrotesk',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 20),

          // Network fee
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Network fee',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontFamily: 'FKGrotesk',
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                 
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                     color: Colors.grey,
                    
                  ),
                  child: Icon(Icons.info_outline, color: Colors.grey[800], size: 14)),
                const Spacer(),
                const Text(
                  '0.0000149 SOL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'FKGroteskSemiMono',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Slide to approve
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxSlide = constraints.maxWidth - 56;

                return Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2D35),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Stack(
                    children: [
                      // Yellow fill
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 50),
                        width: 56 + (_slidePosition * maxSlide),
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      // Label
                      Center(
                        child: Text(
                          'Slide to approve',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                            fontFamily: 'FKGrotesk',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Draggable button
                      Positioned(
                        left: _slidePosition * maxSlide,
                        top: 0,
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _slidePosition += details.delta.dx / maxSlide;
                              _slidePosition = _slidePosition.clamp(0.0, 1.0);
                            });
                          },
                          onHorizontalDragEnd: (details) {
                            if (_slidePosition >= _slideThreshold) {
                              widget.onConfirm();
                            } else {
                              setState(() => _slidePosition = 0);
                            }
                          },
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Colors.yellow,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_right,
                              color: Colors.black,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Status Bottom Sheet (Sending / Success / Error)
// ─────────────────────────────────────────────
class _StatusSheet extends StatelessWidget {
  final String status;
  final String? signature;
  final String? error;
  final String? recipientAddress;
  final VoidCallback onClose;
  final VoidCallback? onSaveAddress;

  const _StatusSheet({
    required this.status,
    this.signature,
    this.error,
    this.recipientAddress,
    required this.onClose,
    this.onSaveAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141518),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 12),
              child: status != 'sending'
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: onClose,
                    )
                  : const SizedBox(height: 48),
            ),
          ),

          const SizedBox(height: 8),

          // Lottie / Icon
          SizedBox(
            width: 100,
            height: 100,
            child: status == 'sending'
                ? Lottie.asset(
                    'assets/assets/lottie/send_loop.json',
                    repeat: true,
                  )
                : status == 'success'
                    ? Lottie.asset(
                        'assets/assets/lottie/result_success.json',
                        repeat: false,
                      )
                    : Lottie.asset(
                        'assets/assets/lottie/result_error.json',
                        repeat: false,
                      ),
          ),

          const SizedBox(height: 16),

          // Status text
          Text(
            status == 'sending'
                ? 'Sending'
                : status == 'success'
                    ? 'Success'
                    : 'Failed',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'FKGrotesk',
              fontWeight: FontWeight.bold,
            ),
          ),

          if (status == 'sending')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You can safely close this screen',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontFamily: 'FKGrotesk',
                ),
              ),
            ),

          if (status == 'error' && error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                error!,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontFamily: 'FKGrotesk',
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Success actions
          if (status == 'success' && signature != null) ...[
            const SizedBox(height: 24),

            // Transaction ID row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: signature!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction ID copied'),
                      backgroundColor: Color(0xFF1C1F26),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Row(
                  children: [
                    const Text(
                      'Transaction ID',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'FKGrotesk',
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.copy, color: Colors.grey[500], size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: Colors.white10, height: 1, indent: 20, endIndent: 20),
            const SizedBox(height: 12),

            // Explorer row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: () async {
                  final url = 'https://explorer.solana.com/tx/$signature?cluster=devnet';
                  try {
                    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                  } catch (_) {
                    if (context.mounted) {
                      Clipboard.setData(ClipboardData(text: url));
                    }
                  }
                },
                child: Row(
                  children: [
                    const Text(
                      'Explorer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'FKGrotesk',
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.open_in_new, color: Colors.grey[500], size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Save address button
            if (onSaveAddress != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: onSaveAddress,
                    child: const Text(
                      'Save address',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontFamily: 'FKGrotesk',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // Close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2D35),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: onClose,
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'FKGrotesk',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
