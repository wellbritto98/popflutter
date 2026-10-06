import 'dart:async';

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:popmundo_utils/src/game_actions/game_transaction.dart';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

const loginHtml =
    '<form method="post" id="aspnetForm" action="/Default.aspx"><input name="__VIEWSTATE" value="fresh-login"><input name="language" value="pt"></form>';
const chooseHtml =
    '<form method="post" id="aspnetForm" action="./ChooseCharacter"><input name="__VIEWSTATE" value="fresh-choice"><div class="box"><h2>Troy Drinkwater</h2><span class="idHolder">3327035</span><input type="submit" name="chooseTroy" value="Escolher Troy"></div><div class="box"><h2>Other Character</h2><span class="idHolder">2</span><input type="submit" name="chooseOther" value="Escolher Other"></div></form>';
const profileHtml =
    '<span class="idHolder">999</span><div class="charPresBox"><span class="idHolder">3327035</span></div>';
const inventoryHtml =
    '<form method="post" id="aspnetForm" action="./"><input name="__VIEWSTATE" value="fresh-items"><table id="checkedlist"><tr><td><a href="/World/Popmundo.aspx/Character/ItemDetails/12">Cubo mágico</a><input type="hidden" name="row1hidItemIDstring" value="fresh-item"><input type="image" name="row1btnUse" src="/Static/Item_Use.png"></td></tr><tr><td><a href="/World/Popmundo.aspx/Character/ItemDetails/13">Violino</a><input type="hidden" name="row2hidItemIDstring" value="fresh-tune"><input type="image" name="row2btnUse" src="/Static/Item_Tune.png"></td></tr></table></form>';
const crewHtml =
    r'<title>(2) Popmundo - black panties</title><form method="post" id="aspnetForm" action="./"><input name="__VIEWSTATE" value="fresh-crew"><div class="entityLogo gameimage idTrigger"><span class="idHolder">2774797</span></div><a href="/World/Popmundo.aspx/Artist/2774797">Informações gerais</a><select name="ctl00$cphLeftColumn$ctl01$ddlCashBonus"><option value="0">Selecionar</option><option value="14">notável 2.250,00 M$</option><option value="20">sobrenatural 123.000,00 M$</option></select><input type="submit" name="ctl00$cphLeftColumn$ctl01$btnCashBonus" value="Entregar bônus"></form>';
final testCharacter = GameCharacter(id: 3327035, name: 'Saved old name');

class FixtureTransport implements GameHttpTransport {
  final requests = <AuthHttpRequest>[];
  bool closed = false;
  String choices = chooseHtml;
  String profile = profileHtml;
  String inventory = inventoryHtml;
  String crew = crewHtml;
  Future<AuthHttpResponse> Function(AuthHttpRequest)? handler;
  @override
  Future<AuthHttpResponse> send(AuthHttpRequest req) async {
    requests.add(req);
    final custom = handler;
    if (custom != null) return custom(req);
    final path = req.url.path;
    if (path == '/Default.aspx' && req.method == 'GET') {
      return const AuthHttpResponse(
        status: 200,
        body: loginHtml,
        setCookieHeaders: ['ASP.NET_SessionId=synthetic-first; Path=/; Secure'],
      );
    }
    if (path == '/Default.aspx') {
      return const AuthHttpResponse(
        status: 302,
        body: '',
        location: 'https://74.popmundo.com/World/Popmundo.aspx/ChooseCharacter',
      );
    }
    if (path.endsWith('/ChooseCharacter') && req.method == 'GET') {
      return AuthHttpResponse(
        status: 200,
        body: choices,
        setCookieHeaders: const [
          'ASP.NET_SessionId=synthetic-private; Path=/; Secure',
        ],
      );
    }
    if (path.endsWith('/ChooseCharacter')) {
      return const AuthHttpResponse(
        status: 302,
        body: '',
        location: '/World/Popmundo.aspx',
      );
    }
    if (path == '/World/Popmundo.aspx/Character') {
      return AuthHttpResponse(status: 200, body: profile);
    }
    if (path.endsWith('/Character/Items/')) {
      return AuthHttpResponse(status: 200, body: inventory);
    }
    if (path.endsWith('/Artist/Crew/')) {
      return AuthHttpResponse(status: 200, body: crew);
    }
    return const AuthHttpResponse(status: 200, body: '<html>home</html>');
  }

  @override
  void close() {
    closed = true;
  }
}

GameActionsService serviceFor(
  FixtureTransport transport, {
  Future<GameCredentials> Function()? credentials,
  GameActionLimits? limits,
}) => GameActionsService(
  createTransport: () => transport,
  readCredentials:
      credentials ??
      () async => const GameCredentials(
        username: 'account',
        password: 'synthetic-password',
      ),
  limits: limits ?? const GameActionLimits(cooldown: Duration.zero),
);
Matcher code(String expected) =>
    throwsA(isA<GameActionException>().having((e) => e.code, 'code', expected));

void main() {
  extraTransportTests();
  protocolAndDiscoveryTests();
  commonFailureTests();
  test(
    'SGA-03 fresh jar, full credential form and assigned host discovery',
    () async {
      final transport = FixtureTransport();
      final result = await serviceFor(transport).discoverCharacters();
      expect(result.toJson(), {
        'username': 'account',
        'characters': [
          {'id': 3327035, 'name': 'Troy Drinkwater'},
          {'id': 2, 'name': 'Other Character'},
        ],
      });
      expect(transport.requests.first.headers.containsKey('Cookie'), false);
      expect(transport.requests[2].headers.containsKey('Cookie'), false);
      expect(
        transport.requests[1].body,
        contains('__VIEWSTATE=fresh-login&language=pt'),
      );
      expect(
        transport.requests[1].body,
        contains('txtPassword=synthetic-password'),
      );
      expect(transport.requests.last.url.host, '74.popmundo.com');
      expect(transport.closed, true);
    },
  );
  test(
    'SGA-02/03 selection governed by ID and fresh scoped profile not name',
    () async {
      final transport = FixtureTransport();
      final choices = await serviceFor(transport)
          .discoverItems(boundUsername: 'account', character: testCharacter);
      expect(choices.map((i) => i.toJson()).toList(), [
        {'name': 'Cubo mágico'},
      ]);
      final selected = transport.requests.firstWhere(
        (r) => r.method == 'POST' && r.url.path.endsWith('ChooseCharacter'),
      );
      expect(
        selected.body,
        '__VIEWSTATE=fresh-choice&__EVENTTARGET=&__EVENTARGUMENT=&chooseTroy=Escolher+Troy',
      );
      expect(selected.headers['Cookie'], 'ASP.NET_SessionId=synthetic-private');
      expect(
        transport.requests.last.url.toString(),
        'https://74.popmundo.com/World/Popmundo.aspx/Character/Items/',
      );
      expect(transport.closed, true);
    },
  );
  test('SGA-02 crew discovery exact artist and quotes in cents', () async {
    final transport = FixtureTransport();
    final options = await serviceFor(transport)
        .discoverCrew(boundUsername: 'account', character: testCharacter);
    expect(options.toJson(), {
      'artistId': 2774797,
      'artistName': 'black panties',
      'bonuses': [
        {'level': 14, 'label': 'notável', 'costMinor': 225000},
        {'level': 20, 'label': 'sobrenatural', 'costMinor': 12300000},
      ],
    });
  });
  for (final wrong in [
    '0',
    '2',
    '3327035</span><span class="idHolder">3327035',
  ]) {
    test('SGA-03 profile mismatch/ambiguity blocks target $wrong', () async {
      final transport = FixtureTransport()
        ..profile =
            '<div class="charPresBox"><span class="idHolder">$wrong</span></div>';
      await expectLater(
        serviceFor(transport)
            .discoverItems(boundUsername: 'account', character: testCharacter),
        code('characterMismatch'),
      );
      expect(
        transport.requests.where((r) => r.url.path.contains('/Items/')),
        isEmpty,
      );
    });
  }
  test('SGA-03 duplicate owned ID cannot select', () async {
    final transport = FixtureTransport()
      ..choices = chooseHtml.replaceAll('>2</span>', '>3327035</span>');
    await expectLater(
      serviceFor(transport)
          .discoverItems(boundUsername: 'account', character: testCharacter),
      code('characterAmbiguous'),
    );
    expect(
      transport.requests.where(
        (r) => r.method == 'POST' && r.url.path.endsWith('/ChooseCharacter'),
      ),
      isEmpty,
    );
  });
  for (final kind in [
    'accountChanged',
    'credentialsMissing',
    'credentialsUnavailable',
  ]) {
    test('SGA-03 fresh credentials $kind prevent HTTP', () async {
      final transport = FixtureTransport();
      final service = serviceFor(
        transport,
        credentials: () async {
          if (kind == 'credentialsUnavailable') {
            throw StateError('synthetic-secret');
          }
          return GameCredentials(
            username: kind == 'accountChanged' ? 'other' : 'account',
            password: kind == 'credentialsMissing' ? '' : 'synthetic-password',
          );
        },
      );
      await expectLater(
        service.discoverItems(
          boundUsername: 'account',
          character: testCharacter,
        ),
        code(kind),
      );
      expect(transport.requests, isEmpty);
      expect(transport.closed, true);
    });
  }
  for (final location in [
    'http://74.popmundo.com/World',
    'https://evil.example/x',
    'https://popmundo.com.evil.example/x',
    'https://user@74.popmundo.com/x',
    'https://74.popmundo.com:444/x',
  ]) {
    test(
      'SGA-03 redirect policy rejects $location before transmission',
      () async {
        final transport = FixtureTransport()
          ..handler = (r) async =>
              AuthHttpResponse(status: 302, body: '', location: location);
        await expectLater(
          serviceFor(transport).discoverCharacters(),
          code('unsafeTarget'),
        );
        expect(transport.requests.map((r) => r.url.toString()).toList(), [
          'https://www.popmundo.com/Default.aspx',
        ]);
        expect(transport.closed, true);
      },
    );
  }
  test(
    'SGA-09 timeout aborts before late response can start another request',
    () async {
      final pending = Completer<AuthHttpResponse>();
      final transport = FixtureTransport()..handler = (_) => pending.future;
      final service = serviceFor(
        transport,
        limits: const GameActionLimits(
          cooldown: Duration.zero,
          transactionTimeout: Duration(milliseconds: 20),
          requestTimeout: Duration(seconds: 1),
        ),
      );
      await expectLater(
        service.discoverCharacters(),
        code('transactionTimeout'),
      );
      expect(transport.closed, true);
      pending.complete(
        const AuthHttpResponse(
          status: 302,
          body: '',
          location: 'https://74.popmundo.com/late',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(transport.requests.length, 1);
    },
  );
  test('SGA-09 dispose cancels active and queued transactions', () async {
    final pending = Completer<AuthHttpResponse>();
    final transport = FixtureTransport()..handler = (_) => pending.future;
    final service = serviceFor(transport);
    final first = service.discoverCharacters();
    await Future<void>.delayed(Duration.zero);
    final second = service.discoverCharacters();
    final firstCheck = expectLater(first, code('serviceUnavailable'));
    final secondCheck = expectLater(second, code('serviceUnavailable'));
    await service.dispose();
    await Future.wait([firstCheck, secondCheck]);
    expect(transport.closed, true);
    expect(transport.requests.length, 1);
  });
  test('SGA-09 request deadline aborts and sanitizes raw exception', () async {
    final transport = FixtureTransport()
      ..handler = (_) => Completer<AuthHttpResponse>().future;
    await expectLater(
      serviceFor(
        transport,
        limits: const GameActionLimits(
          cooldown: Duration.zero,
          requestTimeout: Duration(milliseconds: 20),
        ),
      ).discoverCharacters(),
      code('requestTimeout'),
    );
    expect(transport.closed, true);
  });
  test(
    'SGA-09 body limit rejects before parsing and sanitized network errors',
    () async {
      final transport = FixtureTransport()
        ..handler = (_) async =>
            const AuthHttpResponse(status: 200, body: '12345');
      await expectLater(
        serviceFor(
          transport,
          limits: const GameActionLimits(
            cooldown: Duration.zero,
            maxDecodedBodyBytes: 4,
          ),
        ).discoverCharacters(),
        code('responseTooLarge'),
      );
      final failed = FixtureTransport()
        ..handler = (_) async =>
            throw StateError('https://74.popmundo.com?t=synthetic-secret');
      await expectLater(
        serviceFor(failed).discoverCharacters(),
        code('networkError'),
      );
    },
  );
  test(
    'SGA-04 strict notification signals prevent stale and mixed success',
    () {
      expect(GameNotificationSignals.parse('{"d":[]}').isNeutral, true);
      expect(
        GameNotificationSignals.parse('{"d":{"Status":0,"Text":"normal"}}')
            .isNeutral,
        true,
      );
      expect(
        GameNotificationSignals.parse(
          '{"d":"[{\\"Status\\":1,\\"Text\\":\\"ok\\"}]"}',
        ).outcome.status,
        GameActionStatus.confirmed,
      );
      expect(
        GameNotificationSignals.parse('{"d":[{"Status":2,"Text":"no"}]}')
            .outcome
            .status,
        GameActionStatus.failed,
      );
      for (final body in [
        '{"d":[]}',
        '{"d":[{"Status":1,"Text":"old"},{"Status":2,"Text":"no"}]}',
        '{"d":{"Status":9,"Text":"?"}}',
        '{"d":{"Status":1}}',
        'invalid',
      ]) {
        expect(
          GameNotificationSignals.parse(body).outcome.status,
          GameActionStatus.uncertain,
        );
      }
    },
  );
}

void extraTransportTests() {
  test('SGA-09 transactions serialize complete authentication and return fresh catalogs', () async {
    final pending = Completer<AuthHttpResponse>();
    final first = FixtureTransport()..handler = (_) => pending.future;
    final second = FixtureTransport();
    var factories = 0;
    final service = GameActionsService(
      createTransport: () => factories++ == 0 ? first : second,
      readCredentials: () async => const GameCredentials(
        username: 'account',
        password: 'synthetic-password',
      ),
      limits: const GameActionLimits(cooldown: Duration.zero),
    );
    final firstWork = service.discoverCharacters();
    await Future<void>.delayed(Duration.zero);
    final secondWork = service.discoverCharacters();
    await Future<void>.delayed(Duration.zero);
    expect(second.requests, isEmpty);
    first.handler = null;
    pending.complete(const AuthHttpResponse(status: 200, body: loginHtml));
    final results = await Future.wait([firstWork, secondWork]);
    expect(results.map((r) => r.characters.first.id).toList(), [
      3327035,
      3327035,
    ]);
    expect(first.closed, true);
    expect(second.closed, true);
    expect(second.requests.first.headers.containsKey('Cookie'), false);
  });
  test(
    'SGA-09 cooldown750 after failed request across fresh transactions',
    () async {
      var time = DateTime.utc(2026);
      final starts = <DateTime>[];
      final delays = <Duration>[];
      var factories = 0;
      final service = GameActionsService(
        createTransport: () {
          final transport = ClockTransport(() => starts.add(time));
          if (factories++ == 0) {
            transport.handler = (_) async =>
                throw StateError('synthetic-failure');
          }
          return transport;
        },
        readCredentials: () async => const GameCredentials(
          username: 'account',
          password: 'synthetic-password',
        ),
        now: () => time,
        sleep: (delay) async {
          delays.add(delay);
          time = time.add(delay);
        },
      );
      await expectLater(service.discoverCharacters(), code('networkError'));
      final result = await service.discoverCharacters();
      expect(result.characters.first.id, 3327035);
      expect(
        starts[1].difference(starts[0]),
        const Duration(milliseconds: 750),
      );
      expect(delays.every((d) => d == const Duration(milliseconds: 750)), true);
      expect(
        starts.last.difference(starts[starts.length - 2]),
        const Duration(milliseconds: 750),
      );
    },
  );
  for (final replacement in [
    'method="get"',
    '',
    'method="post" action="/World/Popmundo.aspx/Artist/Crew/"',
  ]) {
    test('SGA-04 game form rejects wrong method/route $replacement', () async {
      final transport = FixtureTransport()
        ..inventory = inventoryHtml.replaceFirst('method="post"', replacement);
      await expectLater(
        serviceFor(transport)
            .discoverItems(boundUsername: 'account', character: testCharacter),
        code('routeMismatch'),
      );
      expect(
        transport.requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/Items/'),
        ),
        isEmpty,
      );
    });
  }
  test('SGA-03 factory exception sanitized and credentials read anew each transaction', () async {
    final service = GameActionsService(
      createTransport: () => throw StateError('synthetic-secret'),
      readCredentials: () async =>
          const GameCredentials(username: 'account', password: 'p'),
    );
    await expectLater(service.discoverCharacters(), code('networkError'));
    var reads = 0;
    final transports = <FixtureTransport>[];
    final fresh = GameActionsService(
      createTransport: () {
        final t = FixtureTransport();
        transports.add(t);
        return t;
      },
      readCredentials: () async => GameCredentials(
        username: ++reads == 1 ? 'account' : 'changed',
        password: 'p',
      ),
      limits: const GameActionLimits(cooldown: Duration.zero),
    );
    expect((await fresh.discoverCharacters()).username, 'account');
    await expectLater(
      fresh.discoverItems(boundUsername: 'account', character: testCharacter),
      code('accountChanged'),
    );
    expect(transports.last.requests, isEmpty);
  });
  test('SGA-04 full successful controls retain duplicates excluding disabled ancestry', () {
    final doc = parseSyntheticForm();
    final form = AspNetFormData.fromDocument(doc, strictDisabledControls: true);
    expect(form.entries.map((e) => [e.key, e.value]).toList(), [
      ['__VIEWSTATE', 'fresh'],
      ['repeat', 'a'],
      ['repeat', 'b'],
      ['check', 'yes'],
      ['firstLegend', 'allowed'],
      ['multi', 'ok'],
      ['memo', 'text'],
    ]);
    expect(
      AspNetFormData.fromDocument(doc).names,
      contains('disabledFieldset'),
    );
  });
  test('SGA-04 strict notification rejects booleans string statuses and null envelope', () {
    for (final body in [
      '{"d":null}',
      '{"d":{"Status":true,"Text":"ok"}}',
      '{"d":{"Status":"1","Text":"ok"}}',
    ]) {
      final signals = GameNotificationSignals.parse(body);
      expect(signals.isNeutral, false);
      expect(signals.outcome.status, GameActionStatus.uncertain);
    }
  });
}

class ClockTransport extends FixtureTransport {
  ClockTransport(this.onSend);
  final void Function() onSend;
  @override
  Future<AuthHttpResponse> send(AuthHttpRequest request) {
    onSend();
    return super.send(request);
  }
}

html_dom.Document parseSyntheticForm() =>
    html_parser.parse('''<form method="post" id="aspnetForm">
<input name="__VIEWSTATE" value="fresh"><input name="repeat" value="a"><input name="repeat" value="b">
<input disabled name="disabled" value="bad"><input type="checkbox" name="unchecked" value="bad">
<input type="checkbox" checked name="check" value="yes"><input type="image" name="unrelatedImage" src="/use.png">
<input type="submit" name="unrelatedSubmit" value="bad"><input form="other" name="foreignOwner" value="bad">
<fieldset disabled><legend><input name="firstLegend" value="allowed"></legend><input name="disabledFieldset" value="bad"><legend><input name="secondLegend" value="bad"></legend></fieldset>
<select multiple name="multi"><option disabled selected value="bad">bad</option><optgroup disabled><option selected value="groupBad">bad</option></optgroup><option selected value="ok">ok</option></select>
<textarea name="memo">text</textarea></form>''');

void protocolAndDiscoveryTests() {
  for (final bodies in <List<String>>[
    ['{"d":[]}'],
    ['{"d":{"Status":1,"Text":"old"}}', '{"d":{"Status":0,"Text":"normal"}}'],
  ]) {
    test(
      'SGA-04 neutral baseline bounded JSON protocol ${bodies.length} reads',
      () async {
        var index = 0;
        final transport = FixtureTransport()
          ..handler = (_) async =>
              AuthHttpResponse(status: 200, body: bodies[index++]);
        final context = GameTransaction(
          transport: transport,
          limits: const GameActionLimits(cooldown: Duration.zero),
          now: () => DateTime.utc(2026),
          sleep: (_) async {},
          onRequestFinished: (_) {},
        );
        try {
          await context.establishNeutralBaseline(
            Uri.parse('https://74.popmundo.com'),
          );
          expect(index, bodies.length);
          expect(transport.requests.first.body, '{"ts":"1767225600000"}');
          expect(
            transport.requests.first.headers['Content-Type'],
            'application/json; charset=utf-8',
          );
          expect(transport.requests.map((r) => r.url.path).toSet(), {
            '/WebServices/A/Open.asmx/GetPageNotifications',
          });
        } finally {
          context.close();
        }
      },
    );
  }
  for (final body in [
    '{"d":{"Status":1,"Text":"stale"}}',
    '{"d":{"Status":true,"Text":"bad"}}',
  ]) {
    test('SGA-04 no neutral baseline stops at most two reads $body', () async {
      final transport = FixtureTransport()
        ..handler = (_) async => AuthHttpResponse(status: 200, body: body);
      final context = GameTransaction(
        transport: transport,
        limits: const GameActionLimits(cooldown: Duration.zero),
        now: DateTime.now,
        sleep: (_) async {},
        onRequestFinished: (_) {},
      );
      try {
        await expectLater(
          context.establishNeutralBaseline(
            Uri.parse('https://74.popmundo.com'),
          ),
          code('preflightUnavailable'),
        );
        expect(transport.requests.length, body.contains('true') ? 1 : 2);
        expect(context.gameplaySent, false);
      } finally {
        context.close();
      }
    });
  }
  test('SGA-04 outside-form inventory/select cannot become choices', () async {
    final items = FixtureTransport()
      ..inventory = inventoryHtml.replaceFirst(
        '<table id="checkedlist">',
        '</form><table id="checkedlist">',
      );
    expect(
      await serviceFor(items)
          .discoverItems(boundUsername: 'account', character: testCharacter),
      isEmpty,
    );
    final crew = FixtureTransport()
      ..crew = crewHtml.replaceFirst('<select ', '</form><select ');
    expect(
      (await serviceFor(crew).discoverCrew(
        boundUsername: 'account',
        character: testCharacter,
      )).bonuses,
      isEmpty,
    );
  });
  for (final invalid in [
    r'notável 2,250.00 M$',
    r'notável 22.50,00 M$',
    r'notável 123.000,00 M$ 2.250,00 M$',
    r'notável 184467440737095517,00 M$',
  ]) {
    test(
      'SGA-06 ambiguous/unsupported/overflow price not offered $invalid',
      () async {
        final transport = FixtureTransport()
          ..crew = crewHtml.replaceFirst(r'notável 2.250,00 M$', invalid);
        final result = await serviceFor(transport)
            .discoverCrew(boundUsername: 'account', character: testCharacter);
        expect(result.bonuses.map((b) => b.level).toList(), [20]);
      },
    );
  }
  test('SGA-03 missing owned target never submits choose-character', () async {
    final transport = FixtureTransport();
    await expectLater(
      serviceFor(transport).discoverItems(
        boundUsername: 'account',
        character: GameCharacter(id: 999, name: 'Troy Drinkwater'),
      ),
      code('characterUnavailable'),
    );
    expect(
      transport.requests.where(
        (r) => r.method == 'POST' && r.url.path.endsWith('ChooseCharacter'),
      ),
      isEmpty,
    );
  });
}

void commonFailureTests() {
  for (final kind in ['formUnavailable', 'invalidCredentials']) {
    test(
      'SGA-03/04 login $kind sanitized and never selects gameplay',
      () async {
        final original = FixtureTransport();
        final transport = FixtureTransport()
          ..handler = (request) async {
            if ((kind == 'formUnavailable' && request.method == 'GET') ||
                (kind == 'invalidCredentials' && request.method == 'POST')) {
              return AuthHttpResponse(
                status: 200,
                body: kind == 'formUnavailable'
                    ? '<html>no form</html>'
                    : loginHtml,
              );
            }
            return original.send(request);
          };
        await expectLater(
          serviceFor(transport).discoverCharacters(),
          code(kind),
        );
        expect(
          transport.requests.every((r) => r.url.path == '/Default.aspx'),
          true,
        );
        expect(transport.closed, true);
      },
    );
  }
  test(
    'SGA-04 failed outcome HTTP never turns 200/navigation into confirmation',
    () async {
      final transport = FixtureTransport()
        ..handler = (_) async =>
            const AuthHttpResponse(status: 500, body: 'synthetic-secret');
      final context = GameTransaction(
        transport: transport,
        limits: const GameActionLimits(cooldown: Duration.zero),
        now: DateTime.now,
        sleep: (_) async {},
        onRequestFinished: (_) {},
      );
      try {
        final outcome = await context.readOutcome(
          Uri.parse('https://74.popmundo.com'),
        );
        expect(outcome.toJson(), {
          'status': 'uncertain',
          'errorCode': 'outcomeUncertain',
        });
      } finally {
        context.close();
      }
    },
  );
}
