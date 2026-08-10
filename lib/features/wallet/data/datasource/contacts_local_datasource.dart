import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:solfare/core/security/secure_store.dart';

class Contact {
  final String name;
  final String address;

  const Contact({required this.name, required this.address});

  Map<String, dynamic> toJson() => {'name': name, 'address': address};

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        name: json['name'] as String,
        address: json['address'] as String,
      );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  String get truncatedAddress {
    if (address.length <= 8) return address;
    return '${address.substring(0, 4)}...${address.substring(address.length - 4)}';
  }
}

class ContactsLocalDataSource {
  final FlutterSecureStorage _storage;
  static const _contactsKey = 'address_book_contacts';
  static const _recentsKey = 'recent_addresses';

  ContactsLocalDataSource({FlutterSecureStorage? storage})
      : _storage = storage ?? SecureStore.instance;

  Future<List<Contact>> getContacts() async {
    final raw = await _storage.read(key: _contactsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Contact.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveContact(Contact contact) async {
    final contacts = await getContacts();
    contacts.removeWhere((c) => c.address == contact.address);
    contacts.add(contact);
    await _storage.write(key: _contactsKey, value: jsonEncode(contacts.map((c) => c.toJson()).toList()));
  }

  Future<List<Contact>> getRecents() async {
    final raw = await _storage.read(key: _recentsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Contact.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addRecent(Contact contact) async {
    final recents = await getRecents();
    recents.removeWhere((c) => c.address == contact.address);
    recents.insert(0, contact);
    if (recents.length > 10) recents.removeRange(10, recents.length);
    await _storage.write(key: _recentsKey, value: jsonEncode(recents.map((c) => c.toJson()).toList()));
  }
}
