import 'dart:convert';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'game_actions_crew_test.dart' show CrewTransport;
import 'game_actions_transport_test.dart' show crewHtml, serviceFor;

Map<String, Object?> futureBonusJson() => {
  'type': 'payCrew',
  'boundUsername': 'account',
  'character': {'id': 3327035, 'name': 'Troy Drinkwater'},
  'artistId': 2774797,
  'artistName': 'black panties',
  'bonusLevel': 20,
};

PayCrewAction futureBonus() =>
    ScheduledAction.fromJson(futureBonusJson()) as PayCrewAction;

void main() {
  for (final explicitNull in [false, true]) {
    test(
      'SGA-02/06 future bonus roundtrips absent quote null=$explicitNull',
      () {
        final json = futureBonusJson();
        if (explicitNull) json['maxCostMinor'] = null;
        final action = ScheduledAction.fromJson(json) as PayCrewAction;
        final decoded = ScheduledAction.fromJson(
          jsonDecode(jsonEncode(action.toJson())) as Map<String, dynamic>,
        ) as PayCrewAction;
        expect(action.maxCostMinor, isNull);
        expect(decoded.toJson(), {...futureBonusJson(), 'maxCostMinor': null});
        expect(decoded.boundUsername, 'account');
        expect(decoded.character.id, 3327035);
        expect(decoded.character.name, 'Troy Drinkwater');
        expect(decoded.artistId, 2774797);
        expect(decoded.artistName, 'black panties');
        expect(decoded.bonusLevel, 20);
      },
    );
  }

  for (final value in [0, -1, '12300000', 12300000.5, false]) {
    test('SGA-01/06 malformed non-null spending cap rejects $value', () {
      expect(
        () => ScheduledAction.fromJson({
          ...futureBonusJson(),
          'maxCostMinor': value,
        }),
        throwsA(
          isA<SchedulerException>().having(
            (error) => error.code,
            'code',
            'invalidAction',
          ),
        ),
      );
    });
  }

  test(
    'SGA-06 future maximum bonus uses freshly offered price and level20',
    () async {
      final transport = CrewTransport()
        ..crew = crewHtml.replaceFirst('123.000,00', '124.000,00');
      final outcome = await serviceFor(transport).execute(futureBonus());
      expect(outcome.status, GameActionStatus.confirmed);
      expect(outcome.errorCode, isNull);
      final fields = Uri.splitQueryString(transport.gameplay.single.body!);
      expect(fields[r'ctl00$cphLeftColumn$ctl01$ddlCashBonus'], '20');
      expect(
        fields[r'ctl00$cphLeftColumn$ctl01$btnCashBonus'],
        'Entregar bônus',
      );
      expect(fields['__VIEWSTATE'], 'fresh-crew');
      expect(transport.notificationReads, 2);
    },
  );

  test('SGA-06 existing capped maximum still blocks a higher quote', () async {
    final transport = CrewTransport()
      ..crew = crewHtml.replaceFirst('123.000,00', '123.000,01');
    final action = ScheduledAction.fromJson({
      ...futureBonusJson(),
      'maxCostMinor': 12300000,
    }) as PayCrewAction;
    expect(action.toJson()['maxCostMinor'], 12300000);
    final outcome = await serviceFor(transport).execute(action);
    expect(outcome.status, GameActionStatus.unavailable);
    expect(outcome.errorCode, 'bonusUnavailable');
    expect(transport.gameplay, isEmpty);
    expect(transport.notificationReads, 0);
  });

  for (final state in [
    'missingSelect',
    'missingMaximum',
    'invalidPrice',
    'zeroPrice',
    'changedArtist',
  ]) {
    test(
      'SGA-06 unquoted maximum $state performs no payment or fallback',
      () async {
        final transport = CrewTransport()
          ..crew = switch (state) {
            'missingSelect' => crewHtml.replaceFirst(
              r'name="ctl00$cphLeftColumn$ctl01$ddlCashBonus"',
              'name="other"',
            ),
            'missingMaximum' => crewHtml.replaceFirst(
              'value="20"',
              'value="19"',
            ),
            'invalidPrice' => crewHtml.replaceFirst('123.000,00', '123,000.00'),
            'zeroPrice' => crewHtml.replaceFirst('123.000,00', '0,00'),
            _ => crewHtml.replaceFirst('>2774797<', '>9<'),
          };
        final outcome = await serviceFor(transport).execute(futureBonus());
        expect(outcome.status, GameActionStatus.unavailable);
        expect(
          outcome.errorCode,
          state == 'changedArtist' ? 'artistMismatch' : 'bonusUnavailable',
        );
        expect(transport.gameplay, isEmpty);
        expect(transport.notificationReads, 0);
      },
    );
  }
}
