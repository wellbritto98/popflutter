import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One service writer; reload avoids stale per-engine preferences.
class PreferencesSchedulerStore implements SchedulerStore {
  PreferencesSchedulerStore(this.prefs);
  final SharedPreferences prefs;
  @override
  Future<String?> read() async {
    await prefs.reload();
    return prefs.getString(SchedulerSnapshot.storageKey);
  }

  @override
  Future<void> write(String value) async {
    if (!await prefs.setString(SchedulerSnapshot.storageKey, value)) {
      throw const SchedulerException('writeFailed');
    }
  }
}
