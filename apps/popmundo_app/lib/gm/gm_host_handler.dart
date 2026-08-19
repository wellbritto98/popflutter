import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_webview/popmundo_webview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../userscripts/userscript_http.dart';
import 'gm_menu_registry.dart';

typedef GmConnectHeadersLookup = List<String> Function(String scriptId);

/// Handles host GM API calls routed through the JS bridge (`type: 'gm'`).
class GmHostHandler {
  GmHostHandler({
    required this.runtime,
    required this.timedFetch,
    required this.resourceStore,
    required this.menuRegistry,
    required this.notificationController,
    required this.connectHeadersFor,
    GmExternalHttpClient? externalHttp,
  }) : _externalHttp = externalHttp ?? GmExternalHttpClient();

  final InAppPopmundoRuntime runtime;
  final TimedFetch timedFetch;
  final GmResourceStore resourceStore;
  final GmMenuRegistry menuRegistry;
  final GmNotificationController notificationController;
  final GmConnectHeadersLookup connectHeadersFor;
  final GmExternalHttpClient _externalHttp;

  Future<void> handle(GmCallEvent event) async {
    switch (event.action) {
      case 'setClipboard':
        await _setClipboard(event);
      case 'openInTab':
        await _openInTab(event);
      case 'notification':
        _showNotification(event);
      case 'registerMenuCommand':
        _registerMenuCommand(event);
      case 'getResourceUrl':
        await _getResourceUrl(event);
      case 'xmlHttpRequest':
        await _xmlHttpRequest(event);
    }
  }

  Future<void> _setClipboard(GmCallEvent event) async {
    final text = '${event.data['text'] ?? ''}';
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _openInTab(GmCallEvent event) async {
    final raw = '${event.data['url'] ?? ''}';
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      // Best-effort — GM_openInTab is fire-and-forget upstream too.
    }
  }

  void _showNotification(GmCallEvent event) {
    final callId = event.callId ?? '${event.data['callId'] ?? ''}';
    if (callId.isEmpty) return;
    notificationController.show(
      GmNotificationState(
        callId: callId,
        title: '${event.data['title'] ?? 'Popmundo'}',
        text: '${event.data['text'] ?? ''}',
      ),
    );
  }

  void _registerMenuCommand(GmCallEvent event) {
    final commandId = '${event.data['commandId'] ?? event.callId ?? ''}';
    if (commandId.isEmpty) return;
    menuRegistry.register(
      GmMenuCommand(
        scriptId: event.scriptId,
        commandId: commandId,
        caption: '${event.data['caption'] ?? ''}',
      ),
    );
  }

  Future<void> _getResourceUrl(GmCallEvent event) async {
    final callId = event.callId ?? '${event.data['callId'] ?? ''}';
    final name = '${event.data['name'] ?? ''}';
    final type = '${event.data['type'] ?? ''}';
    if (callId.isEmpty) return;

    final entry = await resourceStore.get(event.scriptId, name);
    if (entry == null) {
      await _reply({'callId': callId, 'error': 'No resource named "$name"'});
      return;
    }
    await _reply({
      'callId': callId,
      'objectUrl': entry.toDataUrl(
        overrideMimeType: type.isNotEmpty ? type : null,
      ),
    });
  }

  Future<void> _xmlHttpRequest(GmCallEvent event) async {
    final callId = event.callId ?? '${event.data['callId'] ?? ''}';
    if (callId.isEmpty) return;

    final detailsRaw = event.data['details'];
    if (detailsRaw is! Map) {
      await _emitXhr(callId, 'error', _errorState('Invalid XHR details'));
      return;
    }
    final details = Map<String, dynamic>.from(detailsRaw);
    final urlText = '${details['url'] ?? ''}';
    final uri = Uri.tryParse(urlText);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      await _emitXhr(callId, 'error', _errorState('Bad URL: $urlText'));
      return;
    }

    final connectHeaders = connectHeadersFor(event.scriptId);
    if (!GmConnectPolicy.allows(uri, connectHeaders)) {
      await _emitXhr(callId, 'error', _errorState('Connect denied for ${uri.host}'));
      return;
    }

    final method = '${details['method'] ?? 'GET'}';
    final headers = _stringMap(details['headers']);
    final body = details['data']?.toString();
    final timeoutMs = details['timeout'] is int ? details['timeout'] as int : 30000;
    final timeout = Duration(milliseconds: timeoutMs.clamp(1000, 120000));

    try {
      if (HostTracker.isPopmundoUri(uri)) {
        final result = await timedFetch.fetchResponse(
          uri.toString(),
          options: {
            'method': method,
            'headers': headers,
            if (body != null && body.isNotEmpty) 'body': body,
          },
          useCache: false,
          acceptRedirect: true,
        );
        final state = _successState(
          status: result.status,
          responseText: result.text,
          finalUrl: result.url ?? uri.toString(),
          responseHeaders: result.headers,
        );
        await _emitXhr(callId, 'readystatechange', state.copyWith(readyState: 4));
        await _emitXhr(callId, result.ok ? 'load' : 'error', state);
        await _emitXhr(callId, 'loadend', state);
        return;
      }

      final external = await _externalHttp.send(
        url: uri,
        method: method,
        headers: headers,
        body: body,
        timeout: timeout,
      );
      final ok = external.status >= 200 && external.status < 300;
      final state = _successState(
        status: external.status,
        statusText: external.statusText,
        responseText: external.responseText,
        finalUrl: external.finalUrl,
        responseHeaders: external.responseHeaders,
      );
      await _emitXhr(callId, 'readystatechange', state.copyWith(readyState: 4));
      await _emitXhr(callId, ok ? 'load' : 'error', state);
      await _emitXhr(callId, 'loadend', state);
    } catch (e) {
      final state = _errorState('$e');
      await _emitXhr(callId, 'error', state);
      await _emitXhr(callId, 'loadend', state);
    }
  }

  Map<String, String> _stringMap(Object? raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry('$k', '$v'));
  }

  Map<String, dynamic> _successState({
    required int status,
    String statusText = '',
    required String responseText,
    required String finalUrl,
    Map<String, String> responseHeaders = const {},
  }) {
    return {
      'readyState': 4,
      'status': status,
      'statusText': statusText,
      'responseText': responseText,
      'responseHeaders': responseHeaders,
      'finalUrl': finalUrl,
    };
  }

  Map<String, dynamic> _errorState(String message) {
    return {
      'readyState': 4,
      'status': 0,
      'statusText': message,
      'responseText': '',
      'responseHeaders': <String, String>{},
      'finalUrl': '',
    };
  }

  Future<void> _emitXhr(
    String callId,
    String eventType,
    Map<String, dynamic> responseState,
  ) async {
    await _reply({
      'callId': callId,
      'eventType': eventType,
      'responseState': responseState,
    });
  }

  Future<void> _reply(Map<String, dynamic> payload) async {
    final encoded = jsonEncode(payload);
    try {
      await runtime.evaluate('window.__popmundo.gmReply($encoded);');
    } on PopmundoRuntimeException {
      // WebView may be detached during teardown.
    }
  }

  Future<void> onMenuCommandTapped(GmMenuCommand command) async {
    await _reply({
      'action': 'menuClick',
      'scriptId': command.scriptId,
      'commandId': command.commandId,
    });
  }

  Future<void> onNotificationTapped(GmNotificationState notification) async {
    await _reply({
      'action': 'notificationClick',
      'callId': notification.callId,
    });
  }
}

extension on Map<String, dynamic> {
  Map<String, dynamic> copyWith({int? readyState}) {
    return {
      ...this,
      'readyState': ?readyState,
    };
  }
}
