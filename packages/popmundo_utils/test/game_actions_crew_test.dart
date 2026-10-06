import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'game_actions_transport_test.dart'
    show FixtureTransport, crewHtml, testCharacter, serviceFor;

class CrewTransport extends FixtureTransport {
  final signals = <String>['{"d":[]}', '{"d":{"Status":1,"Text":"done"}}'];
  int notificationReads = 0;
  @override
  Future<AuthHttpResponse> send(AuthHttpRequest request) async {
    if (request.url.path.endsWith('/GetPageNotifications')) {
      requests.add(request);
      return AuthHttpResponse(status: 200, body: signals[notificationReads++]);
    }
    if (request.method == 'POST' &&
        request.url.path.endsWith('/Artist/Crew/')) {
      requests.add(request);
      return const AuthHttpResponse(status: 200, body: '<html>done</html>');
    }
    return super.send(request);
  }

  List<AuthHttpRequest> get gameplay => requests
      .where((r) => r.method == 'POST' && r.url.path.endsWith('/Artist/Crew/'))
      .toList();
}

PayCrewAction crewAction({int level = 14, int cap = 225000}) => PayCrewAction(
  boundUsername: 'account',
  character: testCharacter,
  artistId: 2774797,
  artistName: 'Saved artist label',
  bonusLevel: level,
  maxCostMinor: cap,
);
void main() {
  test(
    'SGA-06 full fresh form posts explicitly selected bonus and actual button',
    () async {
      final transport = CrewTransport()
        ..crew = crewHtml
            .replaceFirst(
              '<input type="submit"',
              '<input name="repeat" value="a"><input name="repeat" value="b"><input type="submit" name="unrelated" value="no"><input type="submit"',
            )
            .replaceFirst('Entregar bônus', 'Actual button');
      final outcome = await serviceFor(transport).execute(crewAction());
      expect(outcome.status, GameActionStatus.confirmed);
      expect(outcome.errorCode, isNull);
      expect(transport.gameplay.single.url.host, '74.popmundo.com');
      expect(
        transport.gameplay.single.body,
        '__VIEWSTATE=fresh-crew&ctl00%24cphLeftColumn%24ctl01%24ddlCashBonus=14&repeat=a&repeat=b&__EVENTTARGET=&__EVENTARGUMENT=&ctl00%24cphLeftColumn%24ctl01%24btnCashBonus=Actual+button',
      );
      expect(transport.notificationReads, 2);
    },
  );
  test(
    'SGA-06 selected level20 only when explicitly approved exact current cap',
    () async {
      final transport = CrewTransport();
      expect(
        (await serviceFor(transport)
                .execute(crewAction(level: 20, cap: 12300000)))
            .status,
        GameActionStatus.confirmed,
      );
      final fields = Uri.splitQueryString(transport.gameplay.single.body!);
      expect(fields[r'ctl00$cphLeftColumn$ctl01$ddlCashBonus'], '20');
      expect(
        fields[r'ctl00$cphLeftColumn$ctl01$btnCashBonus'],
        'Entregar bônus',
      );
    },
  );
  for (final kind in [
    'artistChanged',
    'artistMissing',
    'selectMissing',
    'levelMissing',
    'optionDisabled',
    'selectDisabled',
    'buttonMissing',
    'buttonDisabled',
    'buttonEmpty',
    'invalidPrice',
    'ambiguousPrice',
    'overBudget',
    'formMissing',
  ]) {
    test('SGA-06 $kind unavailable without payment or replacement', () async {
      final transport = CrewTransport()
        ..crew = switch (kind) {
          'artistChanged' => crewHtml.replaceFirst('>2774797<', '>9<'),
          'artistMissing' => crewHtml.replaceFirst(
            'class="idHolder"',
            'class="other"',
          ),
          'selectMissing' => crewHtml.replaceFirst(
            r'name="ctl00$cphLeftColumn$ctl01$ddlCashBonus"',
            'name="other"',
          ),
          'levelMissing' => crewHtml.replaceFirst('value="14"', 'value="15"'),
          'optionDisabled' => crewHtml.replaceFirst(
            '<option value="14"',
            '<option disabled value="14"',
          ),
          'selectDisabled' => crewHtml.replaceFirst(
            '<select',
            '<select disabled',
          ),
          'buttonMissing' => crewHtml.replaceFirst(
            r'name="ctl00$cphLeftColumn$ctl01$btnCashBonus"',
            'name="otherButton"',
          ),
          'buttonDisabled' => crewHtml.replaceFirst(
            '<input type="submit"',
            '<input disabled type="submit"',
          ),
          'buttonEmpty' => crewHtml.replaceFirst(
            'value="Entregar bônus"',
            'value=""',
          ),
          'invalidPrice' => crewHtml.replaceFirst('2.250,00', 'invalid'),
          'ambiguousPrice' => crewHtml.replaceFirst('2.250,00', '2,250.00'),
          'overBudget' => crewHtml.replaceFirst('2.250,00', '2.250,01'),
          _ => crewHtml.replaceAll('id="aspnetForm"', 'id="otherForm"'),
        };
      final outcome = await serviceFor(transport).execute(crewAction());
      expect(outcome.status, GameActionStatus.unavailable);
      expect(
        outcome.errorCode,
        anyOf(
          'artistUnavailable',
          'artistMismatch',
          'bonusUnavailable',
          'formUnavailable',
        ),
      );
      expect(transport.gameplay, isEmpty);
      expect(transport.notificationReads, 0);
    });
  }
  for (final signal in ['{"d":[]}', '{"d":{"Status":2,"Text":"rejected"}}']) {
    test(
      'SGA-08 crew outcome reflects actual signal no resend $signal',
      () async {
        final transport = CrewTransport()..signals[1] = signal;
        final outcome = await serviceFor(transport).execute(crewAction());
        expect(
          outcome.status,
          signal.contains('Status')
              ? GameActionStatus.failed
              : GameActionStatus.uncertain,
        );
        expect(
          outcome.errorCode,
          signal.contains('Status') ? 'serverRejected' : 'outcomeUncertain',
        );
        expect(transport.gameplay.length, 1);
      },
    );
  }
}
