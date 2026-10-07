import 'dart:convert';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:popmundo_app/background/keepalive_task_handler.dart';
import 'package:popmundo_app/scheduler/scheduler_environment.dart';
import 'package:popmundo_app/scheduler/scheduler_runner.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

const fixtureUsername = 'fixture-account';
const fixturePassword = 'synthetic-password';
const fixtureCharacterId = 91002;
const fixtureCharacterName = 'Saved Character';
const fixtureItemName = 'Cubo mágico';
const fixtureOracleKey = 'game_actions.fixture_oracle';
const fixtureHoldKey = 'game_actions.fixture_hold';

const _login =
    '<form method="post" id="aspnetForm" action="/Default.aspx"><input name="__VIEWSTATE" value="fresh-login"><input name="language" value="pt"></form>';
const _choose =
    '<form method="post" id="aspnetForm" action="./ChooseCharacter"><input name="__VIEWSTATE" value="fresh-choice"><div class="box"><h2>Saved Character</h2><span class="idHolder">91002</span><input type="submit" name="chooseSaved" value="Choose Saved"></div><div class="box"><h2>Other Character</h2><span class="idHolder">91003</span><input type="submit" name="chooseOther" value="Choose Other"></div></form>';
const _profile =
    '<span class="idHolder">999</span><div class="charPresBox"><span class="idHolder">91002</span></div>';
const _inventory =
    '<form method="post" id="aspnetForm" action="./"><input name="__VIEWSTATE" value="fresh-items"><input name="repeat" value="one"><input name="repeat" value="two"><table id="checkedlist"><tr><td><a href="/World/Popmundo.aspx/Character/ItemDetails/10">Cubo mágico</a><input type="hidden" name="tunehidItemIDstring" value="fresh-tune"><input type="image" name="tunebtnUse" src="/Static/Item_Tune.png"></td></tr><tr><td><a href="/World/Popmundo.aspx/Character/ItemDetails/12">Cubo mágico</a><input type="hidden" name="firsthidItemIDstring" value="fresh-first"><input type="image" name="firstbtnUse" src="/Static/Item_Use.png"></td></tr><tr><td><a href="/World/Popmundo.aspx/Character/ItemDetails/13">Cubo mágico</a><input type="hidden" name="secondhidItemIDstring" value="fresh-second"><input type="image" name="secondbtnUse" src="/Static/Item_Use.png"></td></tr></table></form>';
const _crew =
    r'<html><head><title>Popmundo - Synthetic Band</title></head><body><div class="entityLogo gameimage idTrigger"><span class="idHolder">92002</span></div><form id="aspnetForm" method="post" action="./"><input name="__VIEWSTATE" value="fresh-crew"><input name="repeat" value="one"><input name="repeat" value="two"><select name="ctl00$cphLeftColumn$ctl01$ddlCashBonus"><option value="0">Choose</option><option value="14">notável 2.250,00 M$</option><option value="20">sobrenatural 123.000,00 M$</option></select><input type="submit" name="ctl00$cphLeftColumn$ctl01$btnCashBonus" value="Entregar bônus"></form></body></html>';

Future<SchedulerSnapshot> fixtureSnapshot() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return SchedulerSnapshot.decode(
    prefs.getString(SchedulerSnapshot.storageKey)!,
  );
}

Future<Map<String, dynamic>> fixtureOracle() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return jsonDecode(prefs.getString(fixtureOracleKey) ?? '{}')
      as Map<String, dynamic>;
}

class LoopbackRewritingTransport implements GameHttpTransport {
  LoopbackRewritingTransport(this.port);
  final int port;
  final _sender = IoAuthHttpSender();
  @override
  Future<AuthHttpResponse> send(AuthHttpRequest request) => _sender.call(
    AuthHttpRequest(
      url: Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: port,
        path: request.url.path,
        query: request.url.hasQuery ? request.url.query : null,
      ),
      method: request.method,
      headers: request.headers,
      body: request.body,
    ),
  );
  @override
  void close() => _sender.close();
}

@pragma('vm:entry-point')
void gameActionsFixtureCallback() {
  FlutterForegroundTask.setTaskHandler(_FixtureHandler());
}

// Server belongs to the secondary engine: no UI isolate or fixed port survives
// process death. The stored callback reconstructs it on Android boot.
class _FixtureHandler extends KeepaliveTaskHandler {
  _FixtureHandler() : super(createRunner: createGameActionsFixtureRunner);
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await super.onDestroy(timestamp, isTimeout);
    await _activeFixture?.close();
    _activeFixture = null;
  }
}

GameActionsLoopback? _activeFixture;
Future<SchedulerRunner> createGameActionsFixtureRunner() async {
  final fixture = _activeFixture ??= await GameActionsLoopback.start();
  return createSchedulerRunner(
    createGameTransport: () => LoopbackRewritingTransport(fixture.server.port),
  );
}

class GameActionsLoopback {
  GameActionsLoopback(this.server, this.prefs, this.oracle);
  final HttpServer server;
  final SharedPreferences prefs;
  final Map<String, dynamic> oracle;
  var _effect = false;
  ScheduledRule? _claimed;

  static Future<GameActionsLoopback> start() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final oracle = jsonDecode(
      prefs.getString(fixtureOracleKey) ??
          '{"boots":0,"starts":[],"posts":[],"violations":[]}',
    ) as Map<String, dynamic>;
    oracle['boots'] = (oracle['boots'] as int) + 1;
    if (oracle['holding'] == true) await prefs.setBool(fixtureHoldKey, false);
    final raw = prefs.getString(SchedulerSnapshot.storageKey);
    if (raw != null) {
      oracle['beforeBoot'] = SchedulerSnapshot.decode(raw).rules
          .map(
            (r) => {
              'id': r.id,
              'claim': r.lastClaim?.plannedUtc.toIso8601String(),
              'result': r.lastResult.status.name,
            },
          )
          .toList();
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fixture = GameActionsLoopback(server, prefs, oracle);
    await fixture._save();
    server.listen(fixture._handle);
    return fixture;
  }

  Future<void> _save() => prefs.setString(fixtureOracleKey, jsonEncode(oracle));
  void _require(bool condition, String code) {
    if (!condition) (oracle['violations'] as List).add(code);
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      _require(
        request.connectionInfo?.remoteAddress.address == '127.0.0.1',
        'nonLoopback',
      );
      final path = request.uri.path;
      final method = request.method;
      final body = await utf8.decoder.bind(request).join();
      final response = request.response;
      if (path == '/Default.aspx' && method == 'GET') {
        await prefs.reload();
        _require(
          request.headers.value(HttpHeaders.cookieHeader) == null,
          'nonEmptyInitialJar',
        );
        final rules = SchedulerSnapshot.decode(
          prefs.getString(SchedulerSnapshot.storageKey)!,
        ).rules;
        final claimed = rules
            .where(
              (r) =>
                  r.lastAttemptUtc != null &&
                  r.lastClaim?.plannedUtc == r.lastAttemptUtc &&
                  r.lastResult.status == ScheduleResultStatus.neverExecuted,
            )
            .toList();
        _require(claimed.length == 1, 'missingDurableClaim');
        _claimed = claimed.length == 1 ? claimed.single : null;
        final rule = _claimed;
        if (rule != null) {
          final cards = await FlutterLocalNotificationsPlugin()
              .getActiveNotifications();
          final notices = cards
              .where((n) => n.id == rule.notificationId)
              .toList();
          final service = rule.action is UseItemAction
              ? 'Use item'
              : 'Pay crew';
          _require(
            notices.length == 1 &&
                notices.single.title == 'Executing $service' &&
                notices.single.body == 'Character: Saved Character',
            'missingStartNotice',
          );
          final slot = rule.lastClaim!.plannedUtc.toIso8601String();
          final starts = oracle['starts'] as List;
          _require(
            !starts.any((v) => v['id'] == rule.id && v['slot'] == slot),
            'replayedClaim',
          );
          starts.add({
            'id': rule.id,
            'slot': slot,
            'notificationId': rule.notificationId,
            'characterId': (rule.action as GameScheduledAction).character.id,
            'notice': notices.length == 1 ? notices.single.title : null,
          });
        }
        response.headers.add(
          HttpHeaders.setCookieHeader,
          'ASP.NET_SessionId=synthetic-first; Path=/; Secure',
        );
        response.write(_login);
      } else if (path == '/Default.aspx') {
        final fields = Uri.splitQueryString(body);
        _require(
          fields[AutoLoginRequests.usernameField] == fixtureUsername &&
              fields[AutoLoginRequests.passwordField] == fixturePassword &&
              fields[AutoLoginRequests.statusField] == '1',
          'secureCredentialsMismatch',
        );
        response.statusCode = HttpStatus.found;
        response.headers.set(
          HttpHeaders.locationHeader,
          'https://74.popmundo.com/World/Popmundo.aspx/ChooseCharacter',
        );
      } else if (path.endsWith('/ChooseCharacter') && method == 'GET') {
        response.headers.add(
          HttpHeaders.setCookieHeader,
          'ASP.NET_SessionId=synthetic-private; Path=/; Secure',
        );
        response.write(_choose);
      } else if (path.endsWith('/ChooseCharacter')) {
        final fields = Uri.splitQueryString(body);
        _require(
          fields['chooseSaved'] == 'Choose Saved' &&
              !fields.containsKey('chooseOther'),
          'wrongCharacter',
        );
        response.statusCode = HttpStatus.found;
        response.headers.set(
          HttpHeaders.locationHeader,
          '/World/Popmundo.aspx',
        );
      } else if (path.endsWith('/Character')) {
        response.write(_profile);
      } else if (path.endsWith('/Character/Items/') ||
          path.endsWith('/Artist/Crew/')) {
        final item = path.endsWith('/Character/Items/');
        if (method == 'GET') {
          _effect = false;
          response.write(item ? _inventory : _crew);
        } else {
          final fields = Uri.splitQueryString(body);
          _require(
            body.contains('repeat=one&repeat=two'),
            'missingRepeatedControls',
          );
          _require(
            fields['__VIEWSTATE'] == (item ? 'fresh-items' : 'fresh-crew'),
            'staleViewstate',
          );
          if (item) {
            _require(
              fields['firstbtnUse.x'] == '1' &&
                  fields['firstbtnUse.y'] == '1' &&
                  fields['firsthidItemIDstring'] == 'fresh-first' &&
                  !fields.keys.any(
                    (k) =>
                        k.startsWith('tunebtnUse') ||
                        k.startsWith('secondbtnUse'),
                  ),
              'wrongItemPost',
            );
          } else {
            _require(
              fields[r'ctl00$cphLeftColumn$ctl01$ddlCashBonus'] == '20' &&
                  fields[r'ctl00$cphLeftColumn$ctl01$btnCashBonus'] ==
                      'Entregar bônus',
              'wrongCrewPost',
            );
          }
          (oracle['posts'] as List).add({
            'id': _claimed?.id,
            'slot': _claimed?.lastClaim?.plannedUtc.toIso8601String(),
            'kind': item ? 'item' : 'crew',
            'characterId': fixtureCharacterId,
          });
          await _save();
          await prefs.reload();
          if (prefs.getBool(fixtureHoldKey) == true) {
            oracle['holding'] = true;
            await _save();
            await Future<void>.delayed(const Duration(seconds: 115));
          }
          _effect = true;
          response.write('<html>done</html>');
        }
      } else if (path.endsWith('/GetPageNotifications')) {
        response.headers.contentType = ContentType.json;
        response.write(
          _effect ? '{"d":{"Status":1,"Text":"done"}}' : '{"d":[]}',
        );
      } else {
        response.write('<html>home</html>');
      }
      await _save();
      await response.close();
    } catch (_) {
      (oracle['violations'] as List).add('fixtureHandlerFailure');
      await _save();
      await request.response.close();
    }
  }

  Future<void> close() => server.close(force: true);
}
