import 'dart:async';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'game_actions_transport_test.dart'
    show
        FixtureTransport,
        inventoryHtml,
        profileHtml,
        testCharacter,
        serviceFor;

class ActionTransport extends FixtureTransport {
  final signals = <String>['{"d":[]}', '{"d":{"Status":1,"Text":"done"}}'];
  Future<AuthHttpResponse> Function(AuthHttpRequest)? onGameplay;
  int notificationReads = 0;
  @override
  Future<AuthHttpResponse> send(AuthHttpRequest request) async {
    if (request.url.path.endsWith('/GetPageNotifications')) {
      requests.add(request);
      return AuthHttpResponse(status: 200, body: signals[notificationReads++]);
    }
    if (request.method == 'POST' &&
        request.url.path.endsWith('/Character/Items/')) {
      requests.add(request);
      return onGameplay != null
          ? onGameplay!(request)
          : const AuthHttpResponse(status: 200, body: '<html>done</html>');
    }
    return super.send(request);
  }

  List<AuthHttpRequest> get gameplay => requests
      .where(
        (r) => r.method == 'POST' && r.url.path.endsWith('/Character/Items/'),
      )
      .toList();
}

UseItemAction itemAction([String name = 'Cubo mágico']) => UseItemAction(
  boundUsername: 'account',
  character: testCharacter,
  itemName: name,
);
void main() {
  guardedItemTests();
  test(
    'SGA-05 full fresh form chooses one exact first eligible use row',
    () async {
      final transport = ActionTransport()
        ..inventory = inventoryHtml.replaceFirst(
          '<table',
          '<input name="repeat" value="a"><input name="repeat" value="b"><input name="__EVENTTARGET" value="old"><input name="__EVENTARGUMENT" value="old"><input type="submit" name="otherSubmit" value="no"><input type="image" name="otherImage" src="/Item_Use.png"><table',
        );
      final outcome = await serviceFor(transport)
          .execute(itemAction(' CUBO   mágico '));
      expect(outcome.status, GameActionStatus.confirmed);
      expect(outcome.errorCode, isNull);
      expect(transport.gameplay.single.url.host, '74.popmundo.com');
      expect(
        transport.gameplay.single.body,
        '__VIEWSTATE=fresh-items&repeat=a&repeat=b&__EVENTTARGET=&__EVENTARGUMENT=&row1hidItemIDstring=fresh-item&row2hidItemIDstring=fresh-tune&row1btnUse.x=1&row1btnUse.y=1',
      );
      expect(transport.notificationReads, 2);
      expect(transport.closed, true);
    },
  );
  test(
    'SGA-05 tune homonym skipped, first eligible matching row selected',
    () async {
      final transport = ActionTransport()
        ..inventory = inventoryHtml
            .replaceFirst('Cubo mágico', 'Other')
            .replaceFirst('Violino', 'Cubo mágico')
            .replaceFirst(
              '</table>',
              '<tr><td><a href="/World/Popmundo.aspx/Character/ItemDetails/14">Cubo mágico</a><input type="hidden" name="newhidItemIDstring" value="runtime-new"><input type="image" name="newbtnUse" src="/Item_Use.png"></td></tr><tr><td><a href="/World/Popmundo.aspx/Character/ItemDetails/15">Cubo mágico</a><input type="hidden" name="lasthidItemIDstring" value="runtime-last"><input type="image" name="lastbtnUse" src="/Item_Use.png"></td></tr></table>',
            );
      expect(
        (await serviceFor(transport).execute(itemAction())).status,
        GameActionStatus.confirmed,
      );
      final fields = Uri.splitQueryString(transport.gameplay.single.body!);
      expect(fields['newbtnUse.x'], '1');
      expect(fields['newbtnUse.y'], '1');
      expect(fields['newhidItemIDstring'], 'runtime-new');
      expect(fields.containsKey('row2btnUse.x'), false);
      expect(fields.containsKey('lastbtnUse.x'), false);
    },
  );
  for (final kind in [
    'absent',
    'substring',
    'tune',
    'wear',
    'disabled',
    'hiddenMissing',
    'nested',
  ]) {
    test('SGA-05 unavailable $kind sends zero gameplay POST', () async {
      final transport = ActionTransport();
      transport.inventory = switch (kind) {
        'absent' => inventoryHtml.replaceAll('Cubo mágico', 'Other'),
        'substring' => inventoryHtml.replaceAll(
          'Cubo mágico',
          'Cubo mágico grande',
        ),
        'tune' => inventoryHtml.replaceAll('/Item_Use.png', '/Item_Tune.png'),
        'wear' => inventoryHtml.replaceAll('/Item_Use.png', '/Item_Wear.png'),
        'disabled' => inventoryHtml.replaceFirst(
          'name="row1btnUse"',
          'disabled name="row1btnUse"',
        ),
        'hiddenMissing' => inventoryHtml.replaceFirst(
          'value="fresh-item"',
          'value=""',
        ),
        _ => inventoryHtml.replaceFirst(
          '<input type="image" name="row1btnUse" src="/Static/Item_Use.png">',
          '<table><tr><td><input type="image" name="row1btnUse" src="/Static/Item_Use.png"></td></tr></table>',
        ),
      };
      final outcome = await serviceFor(transport).execute(itemAction());
      expect(outcome.status, GameActionStatus.unavailable);
      expect(outcome.errorCode, 'itemUnavailable');
      expect(transport.gameplay, isEmpty);
      expect(transport.notificationReads, 0);
    });
  }
  for (final baseline in ['{"d":{"Status":1,"Text":"old"}}', 'invalid']) {
    test('SGA-04 stale/malformed baseline aborts effect $baseline', () async {
      final transport = ActionTransport()
        ..signals.setAll(0, [baseline, baseline]);
      final outcome = await serviceFor(transport).execute(itemAction());
      expect(outcome.status, GameActionStatus.failed);
      expect(outcome.errorCode, 'preflightUnavailable');
      expect(transport.gameplay, isEmpty);
      expect(transport.notificationReads, lessThanOrEqualTo(2));
    });
  }
  for (final signal in [
    '{"d":[]}',
    '{"d":{"Status":0,"Text":"normal"}}',
    'invalid',
    '{"d":[{"Status":1,"Text":"ok"},{"Status":2,"Text":"no"}]}',
    '{"d":{"Status":9,"Text":"?"}}',
  ]) {
    test('SGA-08 post outcome uncertain no resend $signal', () async {
      final transport = ActionTransport()..signals[1] = signal;
      final outcome = await serviceFor(transport).execute(itemAction());
      expect(outcome.status, GameActionStatus.uncertain);
      expect(outcome.errorCode, 'outcomeUncertain');
      expect(transport.gameplay.length, 1);
    });
  }
  test('SGA-08 fresh explicit rejection records failed', () async {
    final transport = ActionTransport()
      ..signals[1] = '{"d":{"Status":2,"Text":"rejected"}}';
    final outcome = await serviceFor(transport).execute(itemAction());
    expect(outcome.status, GameActionStatus.failed);
    expect(outcome.errorCode, 'serverRejected');
    expect(transport.gameplay.length, 1);
  });
  test('SGA-08 lost gameplay response uncertain and never resent', () async {
    final transport = ActionTransport()
      ..onGameplay = (_) async => throw StateError('synthetic-secret');
    final outcome = await serviceFor(transport).execute(itemAction());
    expect(outcome.status, GameActionStatus.uncertain);
    expect(outcome.errorCode, 'outcomeUncertain');
    expect(transport.gameplay.length, 1);
    expect(transport.notificationReads, 1);
  });
  test('SGA-09 gameplay cancellation closes and late response cannot verify or retry', () async {
    final late = Completer<AuthHttpResponse>();
    final transport = ActionTransport()..onGameplay = (_) => late.future;
    final service = serviceFor(
      transport,
      limits: const GameActionLimits(
        cooldown: Duration.zero,
        requestTimeout: Duration(milliseconds: 20),
      ),
    );
    final outcome = await service.execute(itemAction());
    expect(outcome.status, GameActionStatus.uncertain);
    expect(transport.closed, true);
    late.complete(const AuthHttpResponse(status: 200, body: 'late'));
    await Future<void>.delayed(Duration.zero);
    expect(transport.gameplay.length, 1);
    expect(transport.notificationReads, 1);
  });
}

void guardedItemTests() {
  originPostAndProfileTests();
  test('SGA-03 verified origin cannot change on target GET', () async {
    final changing = _ChangedOriginTransport(
      "/World/Popmundo.aspx/Character/Items/",
    );
    final outcome = await serviceFor(changing).execute(itemAction());
    expect(outcome.status, GameActionStatus.failed);
    expect(outcome.errorCode, 'routeMismatch');
    expect(changing.gameplay, isEmpty);
    expect(changing.requests.last.url.host, '75.popmundo.com');
  });
  for (final markup in [
    '<html>no form</html>',
    '<form method="post" id="aspnetForm" action="./"></form>',
  ]) {
    test(
      'SGA-08 missing or empty item form unavailable no POST $markup',
      () async {
        final transport = ActionTransport()..inventory = markup;
        final outcome = await serviceFor(transport).execute(itemAction());
        expect(outcome.status, GameActionStatus.unavailable);
        expect(outcome.errorCode, 'formUnavailable');
        expect(transport.gameplay, isEmpty);
        expect(transport.notificationReads, 0);
      },
    );
  }
}

class _ChangedOriginTransport extends ActionTransport {
  _ChangedOriginTransport(this.route);
  final String route;
  @override
  Future<AuthHttpResponse> send(AuthHttpRequest request) {
    if (request.method == "GET" && request.url.path == route) {
      requests.add(request);
      return Future.value(
        AuthHttpResponse(
          status: request.url.host == "74.popmundo.com" ? 302 : 200,
          body: request.url.host == "74.popmundo.com"
              ? ""
              : route.endsWith("Items/")
              ? inventoryHtml
              : profileHtml,
          location: request.url.host == "74.popmundo.com"
              ? "https://75.popmundo.com$route"
              : null,
        ),
      );
    }
    return super.send(request);
  }
}

void originPostAndProfileTests() {
  test('SGA-03 scoped profile origin must match verified session', () async {
    final transport = _ChangedOriginTransport('/World/Popmundo.aspx/Character');
    final outcome = await serviceFor(transport).execute(itemAction());
    expect(outcome.status, GameActionStatus.failed);
    expect(outcome.errorCode, 'routeMismatch');
    expect(
      transport.requests.where((r) => r.url.path.endsWith('/Items/')),
      isEmpty,
    );
    expect(transport.gameplay, isEmpty);
  });
  test('SGA-08 cross-host gameplay response is uncertain no resend', () async {
    final transport = ActionTransport()
      ..onGameplay = (_) async => const AuthHttpResponse(
        status: 302,
        body: '',
        location:
            'https://75.popmundo.com/World/Popmundo.aspx/Character/Items/',
      );
    final outcome = await serviceFor(transport).execute(itemAction());
    expect(outcome.status, GameActionStatus.uncertain);
    expect(outcome.errorCode, 'outcomeUncertain');
    expect(transport.gameplay.length, 1);
    expect(transport.notificationReads, 1);
  });
}
