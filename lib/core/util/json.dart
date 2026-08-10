/// Typed reads over JSON that came off the network.
///
/// A wallet parses account data it did not write, from an RPC it does not
/// control, whose shape changes with the encoding it happened to pick. Going
/// through `dynamic` means every one of those reads is a NoSuchMethodError or
/// a TypeError waiting on a payload that does not match the assumption — and
/// the audit found several of those being swallowed into `return []`, so the
/// user saw an empty portfolio rather than an error.
///
/// The concrete case that motivated this: `getAccountInfo` is called with
/// `encoding: jsonParsed`, and the RPC falls back to base64 for any account
/// whose owning program has no parser — returning `data` as a **List**
/// (`["<base64>", "base64"]`) rather than a Map. `account['data']?['parsed']`
/// then indexes a List with a String and throws, which in the recipient check
/// collapsed the entire transaction preview.
extension JsonRead on Map<String, dynamic> {
  /// The value at [key] if it is a JSON object, else null.
  ///
  /// Never a cast: a List, a String or a number here all mean "not the shape
  /// I expected", which is a null rather than a crash.
  Map<String, dynamic>? mapAt(String key) {
    final value = this[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  List<dynamic>? listAt(String key) {
    final value = this[key];
    return value is List ? value : null;
  }

  String? stringAt(String key) {
    final value = this[key];
    return value is String ? value : null;
  }

  /// Reads an integer, tolerating the two other shapes an RPC uses for one:
  /// a double (any JSON number may arrive that way) and a decimal string
  /// (how u64 values that do not fit a double are sent).
  int? intAt(String key) {
    final value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? doubleAt(String key) {
    final value = this[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool? boolAt(String key) {
    final value = this[key];
    return value is bool ? value : null;
  }

  /// Follows a chain of object keys, stopping at the first thing that is not
  /// an object. `account.pathAt(['data', 'parsed', 'info'])` is the whole
  /// reason this file exists.
  Map<String, dynamic>? pathAt(List<String> keys) {
    Map<String, dynamic>? current = this;
    for (final key in keys) {
      current = current?.mapAt(key);
      if (current == null) return null;
    }
    return current;
  }
}

/// The same reads for a list element, which arrives as `dynamic` however it
/// was obtained.
Map<String, dynamic>? asJsonMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<dynamic> asJsonList(Object? value) => value is List ? value : const [];
