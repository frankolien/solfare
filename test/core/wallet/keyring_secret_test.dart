import 'dart:convert';
import 'dart:typed_data';

import 'package:bs58/bs58.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solfare/core/wallet/keyring.dart';

void main() {
  const mnemonic = 'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon about';

  // A real keypair, so the address can be checked against the phrase's.
  late List<int> secret64;

  setUpAll(() async {
    final key = await Keyring.privateKeyBytes(mnemonic);
    final pub = await Keyring.publicKeyFor(mnemonic);
    secret64 = [...key, ...pub.publicKey];
  });

  test('a phrase is normalised, not rejected', () {
    expect(Keyring.parseSecret('  ABANDON   abandon abandon abandon abandon '
        'abandon abandon abandon abandon abandon abandon about  '), mnemonic);
  });

  test('base58 64 bytes is recognised as a key', () {
    final parsed = Keyring.parseSecret(base58.encode(Uint8List.fromList(secret64)));

    expect(parsed, isNotNull);
    expect(Keyring.isPrivateKey(parsed!), isTrue);
  });

  test('a solana-keygen JSON array is recognised as a key', () {
    final parsed = Keyring.parseSecret(jsonEncode(secret64));

    expect(parsed, isNotNull);
    expect(Keyring.isPrivateKey(parsed!), isTrue);
  });

  test('both encodings reach the same address as the phrase', () async {
    final fromPhrase = await Keyring.publicKeyFor(mnemonic);
    final fromBase58 = await Keyring.publicKeyFor(
        Keyring.parseSecret(base58.encode(Uint8List.fromList(secret64)))!);
    final fromJson =
        await Keyring.publicKeyFor(Keyring.parseSecret(jsonEncode(secret64))!);

    expect(fromBase58.address, fromPhrase.address);
    expect(fromJson.address, fromPhrase.address);
  });

  test('a private-key wallet still signs', () async {
    final pair = await Keyring.keyPairFor(
        Keyring.parseSecret(jsonEncode(secret64))!);
    final expected = await Keyring.keyPairFor(mnemonic);

    expect(pair.address, expected.address);
  });

  test('rubbish is neither', () {
    for (final input in [
      '',
      '   ',
      'not a phrase at all',
      'abandon abandon abandon',           // too few words
      'zzzz!!!!',                          // not base58
      '[1,2,3]',                           // wrong length
      '[300,1,2]',                         // not bytes
    ]) {
      expect(Keyring.parseSecret(input), isNull, reason: input);
    }
  });

  test('a phrase is never mistaken for a key', () {
    // Words are base58-decodable in principle; anything with a space is a
    // phrase or nothing.
    expect(Keyring.isPrivateKey(Keyring.parseSecret(mnemonic)!), isFalse);
  });
}
