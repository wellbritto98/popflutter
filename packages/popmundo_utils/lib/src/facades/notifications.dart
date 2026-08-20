import 'dart:convert';

import '../core/popmundo_runtime.dart';
import '../core/timed_fetch.dart';

class PageNotification {
  const PageNotification({required this.status, required this.text});

  final String status;
  final String text;
}

class Notifications {
  Notifications(this.runtime, this.timedFetch);

  final PopmundoRuntime runtime;
  final TimedFetch timedFetch;

  static const levels = ['success', 'error', 'normal'];

  Future<Map<String, dynamic>?> createNotification({
    required String level,
    String? id,
    String? textContent,
  }) async {
    if (!levels.contains(level)) {
      throw ArgumentError('Unknown notification level: $level');
    }
    final raw = await runtime.evaluate(
      'window.__popmundo.createNotification(${jsonEncode(level)}, ${jsonEncode(id)}, ${jsonEncode(textContent)})',
    );
    if (raw == null || raw == 'null' || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {'result': decoded};
  }

  Future<Map<String, dynamic>?> notifySuccess({String? id, String? textContent}) =>
      createNotification(level: 'success', id: id, textContent: textContent);

  Future<Map<String, dynamic>?> notifyError({String? id, String? textContent}) =>
      createNotification(level: 'error', id: id, textContent: textContent);

  Future<Map<String, dynamic>?> notifyNormal({String? id, String? textContent}) =>
      createNotification(level: 'normal', id: id, textContent: textContent);

  Future<PageNotification> getPageNotifications() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final text = await timedFetch.fetch(
      '/WebServices/A/Open.asmx/GetPageNotifications',
      options: {
        'method': 'POST',
        'headers': {'Content-Type': 'application/json; charset=utf-8'},
        'body': jsonEncode({'ts': '$ts'}),
      },
      useCache: false,
    );
    return parsePageNotifications(text);
  }

  static PageNotification parsePageNotifications(String responseText) {
    final wrapper = jsonDecode(responseText);
    dynamic raw = wrapper is Map ? wrapper['d'] ?? wrapper : wrapper;
    if (raw is String) raw = jsonDecode(raw);
    Map<String, dynamic>? notification;
    if (raw is List && raw.isNotEmpty) {
      final last = raw.last;
      if (last is Map) notification = Map<String, dynamic>.from(last);
    } else if (raw is Map) {
      notification = Map<String, dynamic>.from(raw);
    }
    if (notification == null) {
      return const PageNotification(status: 'normal', text: '');
    }
    final statusNum = notification['Status'];
    final status = statusNum == 0
        ? 'normal'
        : statusNum == 1
            ? 'success'
            : 'error';
    return PageNotification(status: status, text: '${notification['Text'] ?? ''}');
  }
}
