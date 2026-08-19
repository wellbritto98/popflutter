import 'dart:developer' as developer;

/// Sink for auto-login diagnostics. Injected so tests can capture instead of
/// printing.
typedef AutoLoginTrace = void Function(String message);

/// Default sink: `dart:developer`, visible in `flutter run` and `adb logcat`
/// under the `autologin` tag.
void defaultAutoLoginTrace(String message) =>
    developer.log(message, name: 'autologin');

/// Field names whose values must never reach a log.
const _secretFieldMarkers = <String>['txtPassword', 'password'];

/// Emits [label] followed by [body] split into log-sized chunks.
///
/// Android's logcat truncates a single entry around 4 KB, so a 30 KB page dump
/// silently loses its tail unless it is split.
///
/// [secrets] are removed before anything is written. A raw page dump can carry
/// credentials — an ASP.NET form we submitted stays in the DOM with the
/// password as a plain `value` attribute — so callers MUST pass the password.
void traceChunked(
  AutoLoginTrace trace,
  String label,
  String body, {
  int chunkSize = 800,
  int maxChars = 60000,
  Iterable<String> secrets = const [],
}) {
  final redacted = redactSecrets(body, secrets);
  final text =
      redacted.length > maxChars ? redacted.substring(0, maxChars) : redacted;
  final total = (text.length / chunkSize).ceil();
  trace('$label: ${redacted.length} chars'
      '${redacted.length > maxChars ? ' (truncated to $maxChars)' : ''}'
      ', $total chunk(s)');
  for (var i = 0; i < total; i++) {
    final start = i * chunkSize;
    final end = (start + chunkSize).clamp(0, text.length);
    trace('$label[${i + 1}/$total] ${text.substring(start, end)}');
  }
}

/// Renders form fields for logging, masking password values and shortening
/// VIEWSTATE-sized blobs.
String describeFields(Iterable<MapEntry<String, String>> fields) {
  final parts = <String>[];
  for (final f in fields) {
    parts.add('${f.key}=${_describeValue(f.key, f.value)}');
  }
  return parts.join(', ');
}

String _describeValue(String name, String value) {
  if (_secretFieldMarkers.any(name.contains)) {
    return value.isEmpty ? '<empty>' : '<${value.length} chars, masked>';
  }
  if (value.length > 40) return '<${value.length} chars: ${value.substring(0, 20)}…>';
  if (value.isEmpty) return '<empty>';
  return value;
}

/// Escapes control characters so a name with stray whitespace is visible in a
/// log line — the difference between `Deon Drinkwater` and `Deon Drinkwater`
/// is otherwise invisible.
String visibleName(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    if (rune == 0x20 || (rune >= 0x21 && rune <= 0x7e)) {
      buffer.writeCharCode(rune);
    } else if (rune > 0x7e && rune != 0xa0 && rune != 0x200b) {
      buffer.writeCharCode(rune);
    } else {
      buffer.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
    }
  }
  return buffer.toString();
}

/// Strips credentials from text that is about to be logged.
///
/// Two passes, because either alone leaks: the literal values the caller knows
/// (the stored password), and any `value` attribute on a password field —
/// which catches a secret this code never held, such as one the player typed.
String redactSecrets(String text, Iterable<String> secrets) {
  var out = text;
  for (final secret in secrets) {
    if (secret.isEmpty) continue;
    out = out.replaceAll(secret, '<redacted>');
  }
  return out.replaceAllMapped(
    RegExp(
      r'(<input[^>]*(?:type="password"|name="[^"]*(?:assword|txtPW)[^"]*")[^>]*value=")([^"]*)(")',
      caseSensitive: false,
    ),
    (m) => '${m[1]}<redacted>${m[3]}',
  );
}
