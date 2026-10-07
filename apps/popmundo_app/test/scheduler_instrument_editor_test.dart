import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/scheduler_editor.dart';
import 'package:popmundo_app/scheduler/scheduler_screen.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'fake_background_platform.dart';
import 'fake_scheduler_api.dart';
import 'localization_helpers.dart';
import 'scheduler_editor_test.dart' show field, save;
import 'scheduler_game_editor_test.dart' show Discovery, intervalDraft, tap;

class InstrumentDiscovery extends Discovery {
  @override
  Future<List<GameItemChoice>> discoverItems({
    required String boundUsername,
    required GameCharacter character,
  }) async => [
    GameItemChoice(name: 'Violino'),
    GameItemChoice(name: 'Violino', operation: GameItemOperation.tune),
  ];
}

UseItemAction instrumentAction() => UseItemAction(
  boundUsername: 'bound',
  character: GameCharacter(id: 42, name: 'Saved Character'),
  itemName: 'Violino',
  operation: GameItemOperation.tune,
);

void main() {
  for (final locale in ['en', 'pt']) {
    final pt = locale == 'pt';
    testWidgets(
      [
        locale,
        ' instrument choice saves tune and distinguishes same-name use',
      ].join(),
      (tester) async {
        final api = FakeSchedulerApi();
        await pumpLocalized(
          tester,
          SchedulerEditor(
            api: api,
            discovery: InstrumentDiscovery(),
            ensurePermission: () async => true,
          ),
          startLocale: Locale(locale),
        );
        await field(tester, 'schedule-name', 'Tune instrument');
        await tap(tester, const Key('schedule-service-item'));
        await tap(tester, const Key('schedule-character-42'));
        final use = find.byKey(const Key('schedule-item-Violino'));
        final tune = find.byKey(const Key('schedule-item-tune-Violino'));
        expect(use, findsOneWidget);
        expect(tune, findsOneWidget);
        expect(
          find.text(
            pt ? 'Afinar instrumento: Violino' : 'Tune instrument: Violino',
          ),
          findsOneWidget,
        );
        await tap(tester, const Key('schedule-item-Violino'));
        expect(tester.widget<ChoiceChip>(use).selected, true);
        expect(tester.widget<ChoiceChip>(tune).selected, false);
        await tap(tester, const Key('schedule-item-tune-Violino'));
        expect(tester.widget<ChoiceChip>(use).selected, false);
        expect(tester.widget<ChoiceChip>(tune).selected, true);
        expect(
          find.text(
            pt
                ? 'Cada ocorrência elegível afina o instrumento Violino para Saved Character.'
                : 'Each eligible occurrence tunes the instrument Violino for Saved Character.',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(pt ? 'usa um Violino' : 'uses one Violino'),
          findsNothing,
        );
        await save(tester);
        final stored = SchedulerSnapshot.decode(api.store.raw!).rules.single;
        final action = stored.action as UseItemAction;
        expect(action.operation, GameItemOperation.tune);
        expect(action.itemName, 'Violino');
        expect(action.character.toJson(), {
          'id': 42,
          'name': 'Saved Character',
        });
        expect(action.boundUsername, 'bound');
        expect(action.toJson()['operation'], 'tune');
      },
    );

    testWidgets(
      [
        locale,
        ' saved tune edits offline and preserves operation and cadence',
      ].join(),
      (tester) async {
        final api = FakeSchedulerApi();
        final original = (await api.create(
          intervalDraft(instrumentAction()),
          id: 'saved-tune',
        )).rules.single;
        final discovery = InstrumentDiscovery();
        await pumpLocalized(
          tester,
          SchedulerEditor(
            api: api,
            discovery: discovery,
            rule: original,
            ensurePermission: () async => true,
          ),
          startLocale: Locale(locale),
        );
        expect(
          find.text(
            pt
                ? 'Cada ocorrência elegível afina o instrumento Violino para Saved Character.'
                : 'Each eligible occurrence tunes the instrument Violino for Saved Character.',
          ),
          findsOneWidget,
        );
        await field(tester, 'schedule-name', 'Renamed tune');
        await save(tester);
        final updated = SchedulerSnapshot.decode(api.store.raw!).rules.single;
        expect(updated.action.toJson(), instrumentAction().toJson());
        expect(updated.name, 'Renamed tune');
        expect(updated.id, original.id);
        expect(updated.notificationId, original.notificationId);
        expect(updated.recurrence.toJson(), original.recurrence.toJson());
        expect(updated.nextDueUtc, original.nextDueUtc);
        expect(discovery.charactersCalls, 0);
        expect(api.updates, 1);
      },
    );

    testWidgets(
      [locale, ' card names tune instrument rather than use item'].join(),
      (tester) async {
        final api = FakeSchedulerApi();
        await api.create(intervalDraft(instrumentAction()), id: 'tune-card');
        await pumpLocalized(
          tester,
          SchedulerScreen(api: api, platform: FakeBackgroundPlatform()),
          startLocale: Locale(locale),
        );
        expect(
          find.text(
            pt
                ? 'Afinar instrumento para Saved Character: Violino'
                : 'Tune instrument for Saved Character: Violino',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            pt
                ? 'Usar item para Saved Character: Violino'
                : 'Use item for Saved Character: Violino',
          ),
          findsNothing,
        );
      },
    );
  }

  testWidgets(
    'changing only use to tune keeps rule identity and future cadence',
    (tester) async {
      final api = FakeSchedulerApi();
      final original = (await api.create(
        intervalDraft(
          UseItemAction(
            boundUsername: 'bound',
            character: GameCharacter(id: 42, name: 'Saved Character'),
            itemName: 'Violino',
          ),
        ),
        id: 'change-operation',
      )).rules.single;
      await pumpLocalized(
        tester,
        SchedulerEditor(
          api: api,
          discovery: InstrumentDiscovery(),
          rule: original,
          ensurePermission: () async => true,
        ),
      );
      await tap(tester, const Key('schedule-change-target'));
      await tap(tester, const Key('schedule-character-42'));
      await tap(tester, const Key('schedule-item-tune-Violino'));
      await save(tester);
      final updated = SchedulerSnapshot.decode(api.store.raw!).rules.single;
      expect(
        (updated.action as UseItemAction).operation,
        GameItemOperation.tune,
      );
      expect((updated.action as UseItemAction).itemName, 'Violino');
      expect(updated.id, original.id);
      expect(updated.notificationId, original.notificationId);
      expect(updated.recurrence.toJson(), original.recurrence.toJson());
      expect(updated.nextDueUtc, original.nextDueUtc);
      expect(api.updates, 1);
    },
  );
}
