import 'package:flutter/material.dart';
import 'package:solfare/features/wallet/data/datasource/contacts_local_datasource.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  final _dataSource = ContactsLocalDataSource();
  final _searchController = TextEditingController();

  List<Contact> _contacts = [];
  List<Contact> _recents = [];
  List<Contact> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await _dataSource.getContacts();
    final recents = await _dataSource.getRecents();
    setState(() {
      _contacts = contacts;
      _recents = recents;
      _filtered = contacts;
      _isLoading = false;
    });
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _contacts;
      } else {
        _filtered = _contacts
            .where((c) =>
                c.name.toLowerCase().contains(query.toLowerCase()) ||
                c.address.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _showAddContactSheet() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: Color(0xFF0E1014),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
              ),

              const Text(
                'Add Contact',
                style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),

              // Name field
              _buildTextField(nameController, 'Name'),
              const SizedBox(height: 12),

              // Address field
              _buildTextField(addressController, 'Wallet address'),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final address = addressController.text.trim();
                    if (name.isEmpty || address.isEmpty) return;

                    await _dataSource.saveContact(Contact(name: name, address: address));
                    if (mounted) Navigator.pop(context);
                    _loadContacts();
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.black, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk'),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'FKGrotesk'),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0b12),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 8),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          hintText: 'Search',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12, fontFamily: 'FKGrotesk'),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        onChanged: _onSearch,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.yellow, strokeWidth: 2))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Contacts section
                          if (_filtered.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(
                              'CONTACTS',
                              style: TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500, letterSpacing: 1),
                            ),
                            const SizedBox(height: 12),
                            ..._filtered.map((c) => _buildContactRow(c)),
                          ],

                          // Recents section
                          if (_recents.isNotEmpty && _searchController.text.isEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              'RECENT',
                              style: TextStyle(color: Colors.grey[600], fontSize: 10, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500, letterSpacing: 1),
                            ),
                            const SizedBox(height: 12),
                            ..._recents.map((c) => _buildContactRow(c)),
                          ],

                          // Empty state
                          if (_filtered.isEmpty && _recents.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 60),
                              child: Center(
                                child: Text(
                                  'No contacts yet',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12, fontFamily: 'FKGrotesk'),
                                ),
                              ),
                            ),

                          const SizedBox(height: 40),
                        ],
                      ),
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
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Address book',
                style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
              ),
            ),
          ),
          GestureDetector(
            onTap: _showAddContactSheet,
            child: const Icon(Icons.add, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(Contact contact) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          // Initials avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                contact.initials,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + address
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contact.name,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'FKGrotesk', fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                contact.truncatedAddress,
                style: TextStyle(color: Colors.grey[500], fontSize: 10, fontFamily: 'FKGrotesk'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
