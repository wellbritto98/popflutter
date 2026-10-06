import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs_store.dart';

/// Never caches a secret/settings snapshot across engine transactions.
Future<GameCredentials> readSavedGameCredentials(
  SharedPreferences prefs,
  SecretStore secrets,
) async {
  try {
    await prefs.reload();
    final settings = await AutoLoginSettingsStore(SharedPreferencesStore(prefs))
        .load();
    final password = await secrets.read(
      AutoLoginSettingsStore.passwordSecretKey,
    );
    return GameCredentials(
      username: settings.username,
      password: password ?? '',
      status: settings.status,
    );
  } catch (_) {
    throw const GameActionException('credentialsUnavailable');
  }
}
