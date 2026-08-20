/// One item from the game's own `GetMenuNotifications` webservice
/// (item offers, contracts, rezoning requests, etc.).
class MenuNotification {
  const MenuNotification({
    required this.uid,
    required this.dateCreated,
    required this.timeCreated,
    required this.text,
    required this.url,
    required this.repeats,
    required this.type,
    required this.int1,
  });

  final String uid;
  final String dateCreated;
  final String timeCreated;
  final String text;
  final String url;
  final int repeats;
  final int type;
  final int int1;

  /// Parses one entry from the `GetMenuNotifications` response array.
  ///
  /// Field names follow the same PascalCase ASP.NET ScriptService convention
  /// already observed on `GetPageNotifications` (`Status`/`Text`) elsewhere in
  /// this codebase. Coercion mirrors `AutoLoginSettings.fromJson`: strings
  /// default to `''`, ints default to `0`.
  ///
  /// Returns null when [raw] isn't a map, or when it has no usable `UID` —
  /// `UID` is the sole dedup key downstream, so an entry without one can't be
  /// told apart from any other entry without one and is dropped as malformed.
  static MenuNotification? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);

    String stringOf(String key) => '${map[key] ?? ''}';
    int intOf(String key) {
      final value = map[key];
      return value is int ? value : int.tryParse('${value ?? 0}') ?? 0;
    }

    final uid = stringOf('UID');
    if (uid.isEmpty) return null;

    return MenuNotification(
      uid: uid,
      dateCreated: stringOf('DateCreated'),
      timeCreated: stringOf('TimeCreated'),
      text: stringOf('Text'),
      url: stringOf('Url'),
      repeats: intOf('Repeats'),
      type: intOf('Type'),
      int1: intOf('Int1'),
    );
  }
}
