import 'dart:convert';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'game_actions_item_test.dart' show ActionTransport;
import 'game_actions_transport_test.dart'
    show inventoryHtml, testCharacter, serviceFor;

Map<String, Object?> itemJson({String name = 'Violino', String? operation}) => {
  'type': 'useItem',
  'boundUsername': 'account',
  'character': testCharacter.toJson(),
  'itemName': name,
  'operation': ?operation,
};
UseItemAction itemWith(String name, String? operation) =>
    ScheduledAction.fromJson(itemJson(name: name, operation: operation))
        as UseItemAction;

void main() {
  test('F3/SGA-01 explicit tune survives action JSON roundtrip', () {
    final json = itemJson(operation: 'tune');
    final decoded = ScheduledAction.fromJson(
      jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
    );
    expect(decoded.toJson(), json);
    expect((decoded as UseItemAction).character.id, testCharacter.id);
    expect(decoded.character.name, testCharacter.name);
    expect(decoded.boundUsername, 'account');
  });
  test('F3/SGA-01 absent or explicit use keeps legacy action shape', () {
    final legacy = itemJson();
    expect(ScheduledAction.fromJson(legacy).toJson(), legacy);
    expect(
      ScheduledAction.fromJson({...legacy, 'operation': 'use'}).toJson(),
      legacy,
    );
    expect(GameItemChoice.fromJson({'name': 'Violino'}).toJson(), {
      'name': 'Violino',
    });
    expect(
      GameItemChoice.fromJson({'name': 'Violino', 'operation': 'use'}).toJson(),
      {'name': 'Violino'},
    );
  });
  test('F3/SGA-02 tune choice survives discovery RPC JSON roundtrip', () {
    final json = {'name': 'Violino', 'operation': 'tune'};
    expect(
      GameItemChoice.fromJson(jsonDecode(jsonEncode(json)) as Map).toJson(),
      json,
    );
  });
  for (final value in [null, 'wear', 'Tune', '', 1, false]) {
    test('F3/SGA-01 invalid operation rejects action and DTO $value', () {
      final invalid = throwsA(
        isA<SchedulerException>().having(
          (error) => error.code,
          'code',
          'invalidAction',
        ),
      );
      expect(
        () => ScheduledAction.fromJson({...itemJson(), 'operation': value}),
        invalid,
      );
      expect(
        () => GameItemChoice.fromJson({'name': 'Violino', 'operation': value}),
        invalid,
      );
    });
  }
  test(
    'F3/SGA-02 discover use and tune pairs without duplicate instruments',
    () async {
      final transport = ActionTransport()
        ..inventory = inventoryHtml.replaceFirst(
          '</table>',
          '<tr><td><a href="/World/Popmundo.aspx/Character/ItemDetails/14">  vIOlIno  </a><input type="hidden" name="row3hidItemIDstring" value="fresh-third"><input type="image" name="row3btnUse" src="../../../../Static/Icons/Item_Tune.png"></td></tr>'
              '<tr><td><a href="/World/Popmundo.aspx/Character/ItemDetails/15">Violino</a><input type="hidden" name="row4hidItemIDstring" value="fresh-fourth"><input type="image" name="row4btnUse" src="/Static/Item_Use.png"></td></tr></table>',
        );
      final choices = await serviceFor(transport)
          .discoverItems(boundUsername: 'account', character: testCharacter);
      expect(choices.map((choice) => choice.toJson()).toList(), [
        {'name': 'Cubo mágico'},
        {'name': 'Violino', 'operation': 'tune'},
        {'name': 'Violino'},
      ]);
    },
  );
  test(
    'F3/SGA-05 tune posts first exact matching operation and fresh full form',
    () async {
      final transport = ActionTransport()
        ..inventory = inventoryHtml
            .replaceFirst(
              '/Static/Item_Tune.png',
              '../../../../Static/Icons/Item_Tune.png',
            )
            .replaceFirst('Cubo mágico', 'Violino')
            .replaceFirst(
              '<table',
              '<input name="repeat" value="a"><input name="repeat" value="b"><table',
            )
            .replaceFirst(
              '</table>',
              '<tr><td><a href="/World/Popmundo.aspx/Character/ItemDetails/14">Violino</a><input type="hidden" name="row3hidItemIDstring" value="fresh-third"><input type="image" name="row3btnUse" src="/Static/Item_Tune.png"></td></tr></table>',
            );
      final outcome = await serviceFor(transport)
          .execute(itemWith(' VIOLINO ', 'tune'));
      expect(outcome.status, GameActionStatus.confirmed);
      expect(outcome.errorCode, isNull);
      expect(
        transport.gameplay.single.body,
        '__VIEWSTATE=fresh-items&repeat=a&repeat=b&row1hidItemIDstring=fresh-item&row2hidItemIDstring=fresh-tune&row3hidItemIDstring=fresh-third&__EVENTTARGET=&__EVENTARGUMENT=&row2btnUse.x=1&row2btnUse.y=1',
      );
      expect(transport.notificationReads, 2);
    },
  );
  for (final kind in [
    'defaultUseNeverTunes',
    'tuneNeverUses',
    'ambiguous',
    'disabled',
    'wear',
    'discard',
    'wrongBasename',
    'hiddenMissing',
  ]) {
    test('F3/SGA-05 $kind no POST and no operation fallback', () async {
      final transport = ActionTransport();
      final action = kind == 'defaultUseNeverTunes'
          ? itemWith('Violino', null)
          : itemWith('Cubo mágico', 'tune');
      transport.inventory = switch (kind) {
        'defaultUseNeverTunes' || 'tuneNeverUses' => inventoryHtml,
        'ambiguous' =>
          inventoryHtml
              .replaceFirst('/Item_Use.png', '/Item_Tune.png')
              .replaceFirst(
                '</td>',
                '<input type="image" name="extra" src="/Item_Use.png"></td>',
              ),
        'disabled' =>
          inventoryHtml
              .replaceFirst('/Item_Use.png', '/Item_Tune.png')
              .replaceFirst('name="row1btnUse"', 'disabled name="row1btnUse"'),
        'wear' => inventoryHtml.replaceFirst('/Item_Use.png', '/Item_Wear.png'),
        'discard' => inventoryHtml.replaceFirst(
          '/Item_Use.png',
          '/Item_Discard.png',
        ),
        'wrongBasename' => inventoryHtml.replaceFirst(
          '/Item_Use.png',
          '/NotItem_Tune.png',
        ),
        _ =>
          inventoryHtml
              .replaceFirst('/Item_Use.png', '/Item_Tune.png')
              .replaceFirst('value="fresh-item"', 'value=""'),
      };
      final outcome = await serviceFor(transport).execute(action);
      expect(outcome.status, GameActionStatus.unavailable);
      expect(outcome.errorCode, 'itemUnavailable');
      expect(transport.gameplay, isEmpty);
      expect(transport.notificationReads, 0);
    });
  }
}
