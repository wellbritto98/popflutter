import 'dart:convert';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  final character = {'id': 3327035, 'name': 'Troy Drinkwater'};
  final item = {
    'type': 'useItem',
    'boundUsername': 'account',
    'character': character,
    'itemName': 'Cubo mágico',
  };
  final crew = {
    'type': 'payCrew',
    'boundUsername': 'account',
    'character': character,
    'artistId': 2774797,
    'artistName': 'black panties',
    'bonusLevel': 14,
    'maxCostMinor': 225000,
  };
  test(
    'SGA-01 local constructor and exact legacy action remain compatible',
    () {
      final action = LocalNotificationAction(
        title: ' Reminder ',
        body: ' Body ',
      );
      expect(ScheduledAction.fromJson(action.toJson()).toJson(), {
        'type': 'localNotification',
        'title': 'Reminder',
        'body': 'Body',
      });
      expect(action.title, 'Reminder');
      expect(action.body, 'Body');
    },
  );
  test(
    'SGA-01/03 item retains bound account and explicit character ID/name',
    () {
      final action = ScheduledAction.fromJson(item) as UseItemAction;
      expect(action.toJson(), item);
      expect(action.boundUsername, 'account');
      expect(action.character.id, 3327035);
      expect(action.character.name, 'Troy Drinkwater');
      expect(action.itemName, 'Cubo mágico');
      expect(
        ScheduledAction.fromJson(jsonDecode(jsonEncode(action.toJson())))
            .toJson(),
        item,
      );
    },
  );
  test(
    'SGA-01/06 crew retains artist, explicit level and approved cent cap',
    () {
      final action = ScheduledAction.fromJson(crew) as PayCrewAction;
      expect(action.toJson(), crew);
      expect(action.artistId, 2774797);
      expect(action.artistName, 'black panties');
      expect(action.bonusLevel, 14);
      expect(action.maxCostMinor, 225000);
    },
  );
  test('SGA-02 exact item normalization and UTF16 boundary', () {
    final char = GameCharacter(id: 1, name: ' Troy  Drinkwater ');
    final action = UseItemAction(
      boundUsername: ' account ',
      character: char,
      itemName: ' Cubo  mágico\t ',
    );
    expect(action.toJson(), {
      'type': 'useItem',
      'boundUsername': 'account',
      'character': {'id': 1, 'name': 'Troy Drinkwater'},
      'itemName': 'Cubo mágico',
    });
    final accepted = List.filled(60, '\u{1F600}').join();
    expect(
      UseItemAction(
        boundUsername: 'a',
        character: char,
        itemName: accepted,
      ).itemName.length,
      120,
    );
    expect(
      () => UseItemAction(
        boundUsername: 'a',
        character: char,
        itemName: "$accepted😀",
      ),
      throwsA(
        isA<SchedulerException>().having(
          (e) => e.code,
          'code',
          'invalidAction',
        ),
      ),
    );
  });
  final malformed = <Map<String, Object?>>[
    {'type': 'unknown'},
    {
      ...item,
      'character': {'id': 0, 'name': 'Troy'},
    },
    {
      ...item,
      'character': {'id': '3327035', 'name': 'Troy'},
    },
    {
      ...item,
      'character': {'id': 1, 'name': ''},
    },
    {...item, 'boundUsername': ''},
    {...item, 'itemName': ''},
    {...item, 'itemName': 5},
    {...crew, 'artistId': -1},
    {...crew, 'artistName': ''},
    {...crew, 'bonusLevel': 13},
    {...crew, 'bonusLevel': 21},
    {...crew, 'bonusLevel': '14'},
    {...crew, 'maxCostMinor': 0},
    {...crew, 'maxCostMinor': 2250.5},
  ];
  for (var index = 0; index < malformed.length; index++) {
    test('SGA-01/06 malformed payload rejects case $index', () {
      expect(
        () => ScheduledAction.fromJson(malformed[index]),
        throwsA(
          isA<SchedulerException>().having(
            (e) => e.code,
            'code',
            'invalidAction',
          ),
        ),
      );
    });
  }
  test(
    'SGA-01/03 codecs whitelist configuration and discard secret extras',
    () {
      final decoded = ScheduledAction.fromJson({
        ...crew,
        'password': 'synthetic-secret',
        'cookie': 'synthetic-cookie',
        '__VIEWSTATE': 'synthetic-state',
      });
      expect(decoded.toJson(), crew);
      expect(jsonEncode(decoded.toJson()), isNot(contains('synthetic')));
    },
  );
  test('SGA-02 discovery DTOs roundtrip only owned public choices', () {
    final chars = GameCharacterCatalog.fromJson({
      'username': 'account',
      'characters': [character],
    });
    expect(chars.toJson(), {
      'username': 'account',
      'characters': [character],
    });
    final items = GameItemChoice.fromJson({'name': 'Cubo mágico'});
    expect(items.toJson(), {'name': 'Cubo mágico'});
    final options = GameCrewOptions.fromJson({
      'artistId': 2774797,
      'artistName': 'black panties',
      'bonuses': [
        {'level': 14, 'label': 'notável', 'costMinor': 225000},
      ],
    });
    expect(options.toJson(), {
      'artistId': 2774797,
      'artistName': 'black panties',
      'bonuses': [
        {'level': 14, 'label': 'notável', 'costMinor': 225000},
      ],
    });
    expect(
      () => chars.characters.add(GameCharacter(id: 2, name: 'Other')),
      throwsUnsupportedError,
    );
    expect(() => options.bonuses.clear(), throwsUnsupportedError);
  });
  test('SGA-01/02 malformed discovery DTO fields reject safely', () {
    final invalid = <void Function()>[
      () => GameCharacterCatalog.fromJson({'username': '', 'characters': []}),
      () => GameCharacterCatalog.fromJson({
        'username': 'account',
        'characters': [
          {'id': '1', 'name': 'Troy'},
        ],
      }),
      () => GameItemChoice.fromJson({'name': 1}),
      () => GameCrewOptions.fromJson({
        'artistId': '1',
        'artistName': 'Band',
        'bonuses': [],
      }),
      () => GameCrewOptions.fromJson({
        'artistId': 1,
        'artistName': '',
        'bonuses': [],
      }),
      () => GameBonusChoice.fromJson({
        'level': 21,
        'label': 'Invalid',
        'costMinor': 1,
      }),
      () => GameBonusChoice.fromJson({
        'level': 14,
        'label': 'Valid',
        'costMinor': 1.5,
      }),
      () =>
          GameBonusChoice.fromJson({'level': 14, 'label': '', 'costMinor': 1}),
    ];
    for (final decode in invalid) {
      expect(
        decode,
        throwsA(
          isA<SchedulerException>().having(
            (e) => e.code,
            'code',
            'invalidAction',
          ),
        ),
      );
    }
  });
}
