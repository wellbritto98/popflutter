@Tags(['live'])
library;

import 'dart:io';
import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

/// Diagnostics include only route metadata. Never headers, fields or raw URLs.
class _TraceTransport implements GameHttpTransport {
  final GameHttpTransport inner = IoGameHttpTransport();
  bool _closed = false;
  final bool enabled = Platform.environment['POPMUNDO_TRACE_ROUTES'] == 'true';
  @override
  Future<AuthHttpResponse> send(AuthHttpRequest request) async {
    if (enabled) {
      print(
        'game-route request ${request.method} ${request.url.host} ${request.url.path}',
      );
    }
    final response = await inner.send(request);
    if (enabled) {
      print('game-route response status=${response.status}');
      final location = response.location;
      if (location != null) {
        final resolved = AuthSession.resolveLocation(request.url, location);
        if (resolved != null) {
          print('game-route location ${resolved.host} ${resolved.path}');
        }
      }
      final form = html_parser
          .parse(response.body)
          .getElementById('aspnetForm');
      if (form != null) {
        final action = request.url.resolve(form.attributes['action'] ?? '');
        final method = (form.attributes['method'] ?? '').toLowerCase();
        print(
          'game-route form method=$method host=${action.host} path=${action.path}',
        );
      }
    }
    if (Platform.environment["POPMUNDO_PROBE_NOTIFICATIONS"] == "true" &&
        request.method == "GET" &&
        response.status == 200 &&
        request.url.path.endsWith("/Character/Items/")) {
      await _probe(request);
    }
    return response;
  }

  @override
  void close() {
    _closed = true;
    inner.close();
  }

  Future<void> _probe(AuthHttpRequest privateRequest) async {
    for (var read = 0; read < 2; read++) {
      if (_closed) throw const GameActionException('serviceUnavailable');
      await Future<void>.delayed(const Duration(milliseconds: 750));
      if (_closed) throw const GameActionException('serviceUnavailable');
      final response = await inner.send(
        AuthHttpRequest(
          url: privateRequest.url.replace(
            path: '/WebServices/A/Open.asmx/GetPageNotifications',
          ),
          method: 'POST',
          headers: {
            ...privateRequest.headers,
            'Content-Type': 'application/json; charset=utf-8',
            'Origin': privateRequest.url.origin,
          },
          body: jsonEncode({
            'ts': DateTime.now().millisecondsSinceEpoch.toString(),
          }),
        ),
      );
      final signals = GameNotificationSignals.parse(response.body);
      print(
        'game-notifications-live http=${response.status} valid=${signals.valid} statuses=${signals.statuses} neutral=${signals.isNeutral}',
      );
    }
  }
}

/// Opt-in read-only proof; no capture helper or gameplay executor can run here.
void main() {
  final configured =
      (Platform.environment['POPMUNDO_USERNAME'] ?? '').isNotEmpty &&
      (Platform.environment['POPMUNDO_PASSWORD'] ?? '').isNotEmpty;
  test(
    'independent native login selects owned character without gameplay',
    () async {
      final service = GameActionsService(
        createTransport: _TraceTransport.new,
        readCredentials: () async => GameCredentials(
          username: Platform.environment['POPMUNDO_USERNAME'] ?? '',
          password: Platform.environment['POPMUNDO_PASSWORD'] ?? '',
        ),
      );
      try {
        final catalog = await service.discoverCharacters();
        final visibleId = int.parse(
          Platform.environment['POPMUNDO_VISIBLE_CHARACTER_ID']!,
        );
        final requestedId = int.tryParse(
          Platform.environment['POPMUNDO_DISCOVERY_CHARACTER_ID'] ?? '',
        );
        final target = catalog.characters.firstWhere(
          (character) => requestedId == null
              ? character.id != visibleId
              : character.id == requestedId,
        );
        expect(target.id, isNot(visibleId));
        final items = await service.discoverItems(
          boundUsername: catalog.username,
          character: target,
        );
        expect(items.every((item) => item.name.isNotEmpty), true);
        final crewId = int.tryParse(
          Platform.environment['POPMUNDO_DISCOVERY_CREW_CHARACTER_ID'] ?? '',
        );
        if (crewId != null) {
          final crewCharacter = catalog.characters.firstWhere(
            (c) => c.id == crewId,
          );
          final crew = await service.discoverCrew(
            boundUsername: catalog.username,
            character: crewCharacter,
          );
          expect(crew.artistId, greaterThan(0));
          expect(
            crew.bonuses.every(
              (b) => b.level >= 14 && b.level <= 20 && b.costMinor > 0,
            ),
            true,
          );
          print(
            'game-crew-live charId=$crewId artistId=${crew.artistId} levels=${crew.bonuses.map((b) => b.level).toList()} costsMinor=${crew.bonuses.map((b) => b.costMinor).toList()}',
          );
        }
        print(
          'game-discovery-live visibleId=$visibleId selectedId=${target.id} owned=${catalog.characters.length} itemChoices=${items.length}',
        );
      } on GameActionException catch (error) {
        fail('game-discovery-live failed code=${error.code}');
      } finally {
        await service.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: !configured
        ? 'Set runtime POPMUNDO_* credentials for this opt-in live proof.'
        : false,
  );
}
