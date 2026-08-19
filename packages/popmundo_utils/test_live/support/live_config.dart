import 'dart:io';

/// Credentials and switches for the live tier, read from the environment so
/// no secret is ever written into the repo.
///
/// ```bash
/// export POPMUNDO_USERNAME=... POPMUNDO_PASSWORD=... POPMUNDO_CHARACTER='Full Name'
/// ```
class LiveConfig {
  static String? get username => _env('POPMUNDO_USERNAME');
  static String? get password => _env('POPMUNDO_PASSWORD');
  static String? get character => _env('POPMUNDO_CHARACTER');

  /// Status value posted with the login form (`ddlStatus`).
  static String get status => _env('POPMUNDO_STATUS') ?? '0';

  /// Opt-in for the step that actually selects a character. It changes the
  /// account's active character, so it stays off unless asked for.
  static bool get allowCharacterSelect =>
      _env('POPMUNDO_ALLOW_SELECT') == 'true';

  static bool get hasCredentials =>
      (username?.isNotEmpty ?? false) &&
      (password?.isNotEmpty ?? false) &&
      (character?.isNotEmpty ?? false);

  /// Reason string for `skip:` when credentials are absent.
  static String? get skipReason => hasCredentials
      ? null
      : 'set POPMUNDO_USERNAME / POPMUNDO_PASSWORD / POPMUNDO_CHARACTER to run';

  static String? _env(String key) {
    final value = Platform.environment[key];
    return (value == null || value.isEmpty) ? null : value;
  }
}

/// Writes real pages to `test_live/captured/` so offline fixtures can be
/// regenerated from the live site instead of being written from memory.
class LiveCapture {
  static Directory get directory =>
      Directory('${Directory.current.path}/test_live/captured');

  static File fileFor(String name) => File('${directory.path}/$name');

  static void save(String name, String html) {
    directory.createSync(recursive: true);
    fileFor(name).writeAsStringSync(html);
    stdout.writeln('[capture] ${fileFor(name).path} (${html.length} bytes)');
  }

  /// Captured page, or null when it has not been recorded yet.
  static String? read(String name) {
    final file = fileFor(name);
    return file.existsSync() ? file.readAsStringSync() : null;
  }
}

/// Credentials for one live run, resolved once so a test can hold them in a
/// local instead of re-reading the environment at every use.
///
/// [fromEnvironment] returns null when any of the three is missing, which is
/// the signal to skip rather than fail — see [missingMessage].
class LiveCredentials {
  const LiveCredentials({
    required this.username,
    required this.password,
    required this.characterName,
  });

  static LiveCredentials? fromEnvironment() {
    if (!LiveConfig.hasCredentials) return null;
    return LiveCredentials(
      username: LiveConfig.username!,
      password: LiveConfig.password!,
      characterName: LiveConfig.character!,
    );
  }

  /// Reason shown on the skipped test when the environment is not set up.
  static String get missingMessage =>
      LiveConfig.skipReason ?? 'credentials missing';

  final String username;
  final String password;

  /// Full character name, as rendered on the ChooseCharacter page.
  final String characterName;
}
