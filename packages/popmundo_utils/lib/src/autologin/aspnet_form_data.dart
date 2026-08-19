import 'package:html/dom.dart';

/// Ordered `application/x-www-form-urlencoded` payload built from an ASP.NET
/// WebForms `<form>`, mirroring what a browser sends on submit.
///
/// This is the Dart equivalent of the Popmundo-Utils idiom
/// `new FormData(doc.getElementById('aspnetForm'))` → `.set(...)` overrides →
/// `URLSearchParams` (see `features/mass-item-sender.js`
/// `buildOfferItemPostBodyFromDoc`). Serializing the whole form — rather than
/// cherry-picking `__VIEWSTATE` & friends — is what keeps the POST valid when
/// the page carries extra hidden state (`__LASTFOCUS`, `__SCROLLPOSITIONX`,
/// `__VIEWSTATEENCRYPTED`) or extra controls (language / theme selects).
///
/// Pairs are ordered and names may repeat (checkbox lists, multi-selects), so
/// this is a list of entries rather than a `Map`.
class AspNetFormData {
  AspNetFormData(this._entries);

  /// Empty payload — signals "no `<form>` on the page" to callers.
  AspNetFormData.empty() : _entries = <MapEntry<String, String>>[];

  /// Serializes every *successful control* of the form with id [formId].
  ///
  /// Returns an empty instance when the form is absent, which callers treat as
  /// an abort (same as `misOfferFormMissing` in the reference extension).
  factory AspNetFormData.fromDocument(
    Document doc, {
    String formId = 'aspnetForm',
  }) {
    final form = doc.getElementById(formId);
    if (form == null) return AspNetFormData.empty();

    final entries = <MapEntry<String, String>>[];
    for (final el in form.querySelectorAll('input, select, textarea')) {
      final name = el.attributes['name'];
      if (name == null || name.isEmpty) continue;
      if (el.attributes.containsKey('disabled')) continue;

      switch (el.localName) {
        case 'input':
          final type = (el.attributes['type'] ?? 'text').toLowerCase();
          if (_excludedInputTypes.contains(type)) continue;
          if (type == 'checkbox' || type == 'radio') {
            if (!el.attributes.containsKey('checked')) continue;
            entries.add(MapEntry(name, el.attributes['value'] ?? 'on'));
            continue;
          }
          entries.add(MapEntry(name, el.attributes['value'] ?? ''));
        case 'textarea':
          entries.add(MapEntry(name, el.text));
        case 'select':
          entries.addAll(_selectEntries(el, name));
      }
    }
    return AspNetFormData(entries);
  }

  /// Submit-like controls a browser never serializes unless they are the
  /// submitter — which is why callers always `set()` the button explicitly.
  /// `file` is excluded because there is no byte payload to carry here.
  static const _excludedInputTypes = <String>{
    'submit',
    'button',
    'reset',
    'image',
    'file',
  };

  final List<MapEntry<String, String>> _entries;

  bool get isEmpty => _entries.isEmpty;
  bool get isNotEmpty => _entries.isNotEmpty;

  /// Field names in document order (duplicates preserved). Test/debug aid.
  List<String> get names => [for (final e in _entries) e.key];

  /// Name/value pairs in document order — for logging and diagnostics.
  List<MapEntry<String, String>> get entries =>
      List.unmodifiable(_entries);

  /// First value for [name], or null when absent.
  String? operator [](String name) {
    for (final e in _entries) {
      if (e.key == name) return e.value;
    }
    return null;
  }

  /// Replaces the first entry named [name] and drops any duplicates, appending
  /// when the field is absent — same contract as `FormData.set`.
  void set(String name, String value) {
    var replaced = false;
    for (var i = _entries.length - 1; i >= 0; i--) {
      if (_entries[i].key != name) continue;
      if (replaced) {
        _entries.removeAt(i);
      } else {
        _entries[i] = MapEntry(name, value);
        replaced = true;
      }
    }
    if (!replaced) _entries.add(MapEntry(name, value));
  }

  String encode() => [
        for (final e in _entries)
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
      ].join('&');

  static Iterable<MapEntry<String, String>> _selectEntries(
    Element select,
    String name,
  ) {
    final options = select.querySelectorAll('option');
    final selected =
        options.where((o) => o.attributes.containsKey('selected')).toList();
    if (select.attributes.containsKey('multiple')) {
      return [for (final o in selected) MapEntry(name, _optionValue(o))];
    }
    // A non-multiple select always submits something: the marked option, or
    // the first one, which is what the browser pre-selects.
    final chosen = selected.isNotEmpty
        ? selected.first
        : (options.isEmpty ? null : options.first);
    return chosen == null
        ? const <MapEntry<String, String>>[]
        : [MapEntry(name, _optionValue(chosen))];
  }

  static String _optionValue(Element option) =>
      option.attributes['value'] ?? option.text.trim();
}
