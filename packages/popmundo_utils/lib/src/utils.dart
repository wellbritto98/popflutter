import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'host_tracker.dart';
import 'popmundo_runtime.dart';
import 'timed_fetch.dart';

/// Character id/name and host helpers. Id/name come from a cached TimedFetch of
/// `/World/Popmundo.aspx/Character` — the live page's `charPresBox` is absent
/// on most routes and can even belong to someone else on another profile.
class Utils {
  Utils(this.runtime, this.timedFetch);

  final PopmundoRuntime runtime;
  final TimedFetch timedFetch;

  static const characterPath = '/World/Popmundo.aspx/Character';

  HostTracker get host => runtime.host;

  Uri getServerLink(String urlPath) => runtime.host.resolve(urlPath);

  Future<int> getMyID() async => (await getMyCharDetails()).id;

  Future<String> getMyName() async => (await getMyCharDetails()).name;

  Future<({int id, String name})> getMyCharDetails() async {
    try {
      final page = await timedFetch.fetch(characterPath);
      return parseCharDetails(page);
    } on TimedFetchException {
      return (id: 0, name: '');
    } on PopmundoRuntimeException {
      return (id: 0, name: '');
    }
  }

  /// Scrapes [characterPath] HTML. Same selectors as `helpers.js`.
  static ({int id, String name}) parseCharDetails(String source) {
    final doc = html_parser.parse(source);
    return (id: _parseId(doc), name: _parseName(doc));
  }
}

int _parseId(Document doc) {
  final el = doc.querySelector('div.idHolder');
  if (el == null) return 0;
  final id = int.tryParse(el.text.trim());
  if (id == null || id <= 0) return 0;
  return id;
}

/// `#ppm-content > div.box.ofauto.charPresBox > h2` walked as direct children
/// so we don't depend on `package:html`'s chained-class CSS support.
String _parseName(Document doc) {
  final ppm = doc.getElementById('ppm-content');
  if (ppm == null) return '';
  for (final box in ppm.children) {
    if (box.localName != 'div') continue;
    final classes = box.classes;
    if (!classes.contains('box') ||
        !classes.contains('ofauto') ||
        !classes.contains('charPresBox')) {
      continue;
    }
    for (final child in box.children) {
      if (child.localName != 'h2') continue;
      final name = child.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (name.isNotEmpty) return name;
    }
  }
  return '';
}
