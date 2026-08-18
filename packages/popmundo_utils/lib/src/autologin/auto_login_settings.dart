import '../storage.dart';

class AutoLoginSettings {
  const AutoLoginSettings({
    this.enabled = false,
    this.username = '',
    this.characterName = '',
    this.status = 0,
  });

  final bool enabled;
  final String username;
  final String characterName;

  /// Popmundo ddlStatus: 0 Normal, 1 Busy, 2 Mobile, 3 Drunk, 4 Away.
  final int status;

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'username': username,
        'characterName': characterName,
        'status': status,
      };

  factory AutoLoginSettings.fromJson(Object? raw) {
    if (raw is! Map) return const AutoLoginSettings();
    final map = Map<String, dynamic>.from(raw);
    final statusRaw = map['status'];
    final status = statusRaw is int
        ? statusRaw
        : int.tryParse('${statusRaw ?? 0}') ?? 0;
    return AutoLoginSettings(
      enabled: map['enabled'] == true,
      username: '${map['username'] ?? ''}',
      characterName: '${map['characterName'] ?? ''}',
      status: status,
    );
  }

  AutoLoginSettings copyWith({
    bool? enabled,
    String? username,
    String? characterName,
    int? status,
  }) {
    return AutoLoginSettings(
      enabled: enabled ?? this.enabled,
      username: username ?? this.username,
      characterName: characterName ?? this.characterName,
      status: status ?? this.status,
    );
  }
}

class AutoLoginSettingsStore {
  AutoLoginSettingsStore(this.store, {this.storageKey = defaultStorageKey});

  static const defaultStorageKey = 'autologin.v1';
  static const passwordSecretKey = 'autologin.password';

  final KeyValueStore store;
  final String storageKey;

  Future<AutoLoginSettings> load() async {
    return AutoLoginSettings.fromJson(await store.get(storageKey));
  }

  Future<void> save(AutoLoginSettings settings) async {
    await store.set(storageKey, settings.toJson());
  }
}
