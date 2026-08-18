import 'host_tracker.dart';
import 'popmundo_runtime.dart';

class Utils {
  Utils(this.runtime);

  final PopmundoRuntime runtime;

  HostTracker get host => runtime.host;

  Uri getServerLink(String urlPath) => runtime.host.resolve(urlPath);

  Future<int> getMyID() async {
    final raw = await runtime.evaluate('window.__popmundo.getMyID()');
    if (raw == null || raw.isEmpty || raw == 'null') return 0;
    final id = int.tryParse(raw.trim());
    if (id == null || id <= 0) return 0;
    return id;
  }

  Future<String> getMyName() async {
    final raw = await runtime.evaluate('window.__popmundo.getMyName()');
    if (raw == null || raw == 'null') return '';
    return raw;
  }

  Future<({int id, String name})> getMyCharDetails() async {
    final id = await getMyID();
    if (id == 0) return (id: 0, name: '');
    return (id: id, name: await getMyName());
  }
}
