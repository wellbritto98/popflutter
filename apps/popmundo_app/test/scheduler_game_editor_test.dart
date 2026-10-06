import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/scheduler_client.dart';
import 'package:popmundo_app/scheduler/scheduler_editor.dart';
import 'package:popmundo_app/scheduler/scheduler_screen.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'fake_background_platform.dart';
import 'fake_scheduler_api.dart';
import 'localization_helpers.dart';
import 'scheduler_editor_test.dart' show field, save;

class Discovery implements GameActionsApi {
  Discovery({this.failure});
  Object? failure;
  int charactersCalls = 0, itemCalls = 0, crewCalls = 0;
  final character = GameCharacter(id: 42, name: 'Saved Character');
  @override
  Future<GameCharacterCatalog> discoverCharacters() async {
    charactersCalls++;
    final failure = this.failure;
    if (failure != null) throw failure;
    return GameCharacterCatalog(username: 'bound', characters: [character]);
  }

  @override
  Future<List<GameItemChoice>> discoverItems({
    required String boundUsername,
    required GameCharacter character,
  }) async {
    itemCalls++;
    return [
      GameItemChoice(name: 'Exact Item'),
      GameItemChoice(name: 'Other Item'),
    ];
  }

  @override
  Future<GameCrewOptions> discoverCrew({
    required String boundUsername,
    required GameCharacter character,
  }) async {
    crewCalls++;
    return GameCrewOptions(
      artistId: 77,
      artistName: 'Saved Band',
      bonuses: [
        GameBonusChoice(level: 20, label: 'máximo', costMinor: 900000),
        GameBonusChoice(level: 14, label: 'notável', costMinor: 225000),
      ],
    );
  }
}

ScheduleDraft intervalDraft(ScheduledAction action, {String name = 'Saved'}) =>
    ScheduleDraft(
      name: name,
      recurrence: IntervalRecurrence(
        quantity: 10,
        unit: IntervalUnit.seconds,
        anchorUtc: DateTime.utc(2026),
      ),
      action: action,
    );

UseItemAction savedItem() => UseItemAction(
  boundUsername: 'bound',
  character: GameCharacter(id: 42, name: 'Saved Character'),
  itemName: 'Exact Item',
);

Future<void> tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('item save persists owned character and exact discovered name', (
    tester,
  ) async {
    final api = FakeSchedulerApi();
    final discovery = Discovery();
    await pumpLocalized(
      tester,
      SchedulerEditor(
        api: api,
        discovery: discovery,
        ensurePermission: () async => true,
      ),
    );
    expect(find.text('Use item'), findsOneWidget);
    expect(find.text('Pay crew'), findsOneWidget);
    await field(tester, 'schedule-name', 'Morning item');
    await tap(tester, const Key('schedule-service-item'));
    expect(discovery.charactersCalls, 1);
    expect(find.byKey(const Key('schedule-title')), findsNothing);
    await tap(tester, const Key('schedule-character-42'));
    expect(discovery.itemCalls, 1);
    expect(
      find.text(
        'Each eligible occurrence uses one Exact Item for Saved Character.',
      ),
      findsNothing,
    );
    await tap(tester, const Key('schedule-item-Exact Item'));
    expect(
      find.text(
        'Each eligible occurrence uses one Exact Item for Saved Character.',
      ),
      findsOneWidget,
    );
    await save(tester);
    final action = (await api.list()).rules.single.action as UseItemAction;
    expect(action.character.id, 42);
    expect(action.character.name, 'Saved Character');
    expect(action.itemName, 'Exact Item');
    expect(action.boundUsername, 'bound');
    expect(action.toJson().keys, [
      'type',
      'boundUsername',
      'character',
      'itemName',
    ]);
  });

  testWidgets('crew save requires an explicit quote and never defaults to 20', (
    tester,
  ) async {
    final api = FakeSchedulerApi();
    final discovery = Discovery();
    await pumpLocalized(
      tester,
      SchedulerEditor(
        api: api,
        discovery: discovery,
        ensurePermission: () async => true,
      ),
    );
    await field(tester, 'schedule-name', 'Crew bonus');
    await tap(tester, const Key('schedule-service-crew'));
    expect(
      find.text(
        'The game allows one crew bonus every seven days. An unavailable form spends nothing and waits for the next occurrence.',
      ),
      findsOneWidget,
    );
    await tap(tester, const Key('schedule-character-42'));
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('schedule-bonus-20'))).selected,
      false,
    );
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('schedule-bonus-14'))).selected,
      false,
    );
    expect(find.text('Artist: Saved Band'), findsOneWidget);
    expect(find.text('máximo · 900000'), findsOneWidget);
    expect(find.text('notável · 225000'), findsOneWidget);
    await save(tester);
    expect(api.creates, 0);
    expect(
      find.text('Choose a character and an offered option before saving.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('schedule-name')))
          .controller!
          .text,
      'Crew bonus',
    );
    await tap(tester, const Key('schedule-bonus-14'));
    expect(
      find.text(
        'Each eligible occurrence distributes cash bonus 14 (225000) to Saved Band.',
      ),
      findsOneWidget,
    );
    await save(tester);
    final action = (await api.list()).rules.single.action as PayCrewAction;
    expect(action.character.id, 42);
    expect(action.artistId, 77);
    expect(action.artistName, 'Saved Band');
    expect(action.bonusLevel, 14);
    expect(action.maxCostMinor, 225000);
  });

  testWidgets('discovery failure keeps input and does not save a game rule', (
    tester,
  ) async {
    final api = FakeSchedulerApi();
    final discovery = Discovery(
      failure: const SchedulerException('credentialsMissing'),
    );
    await pumpLocalized(
      tester,
      SchedulerEditor(
        api: api,
        discovery: discovery,
        ensurePermission: () async => true,
      ),
    );
    await field(tester, 'schedule-name', 'Kept name');
    await tap(tester, const Key('schedule-service-item'));
    expect(
      find.text('Saved login is incomplete. Nothing was saved.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('schedule-name')))
          .controller!
          .text,
      'Kept name',
    );
    expect(api.creates, 0);
    expect(api.store.raw, isNull);
  });

  testWidgets(
    'saved game rule edits offline and an action-only change keeps cadence',
    (tester) async {
      final api = FakeSchedulerApi();
      final before = (await api.create(
        intervalDraft(savedItem()),
        id: 'existing',
      )).rules.single;
      final discovery = Discovery();
      await pumpLocalized(
        tester,
        SchedulerEditor(
          api: api,
          discovery: discovery,
          rule: before,
          ensurePermission: () async => true,
        ),
      );
      expect(discovery.charactersCalls, 0);
      expect(
        find.text(
          'Each eligible occurrence uses one Exact Item for Saved Character.',
        ),
        findsOneWidget,
      );
      await field(tester, 'schedule-name', 'Renamed');
      await save(tester);
      expect(discovery.charactersCalls, 0);
      final renamed = (await api.list()).rules.single;
      expect(renamed.notificationId, before.notificationId);
      expect(renamed.nextDueUtc, before.nextDueUtc);
      expect(
        (renamed.recurrence as IntervalRecurrence).anchorUtc,
        (before.recurrence as IntervalRecurrence).anchorUtc,
      );
      expect((renamed.action as UseItemAction).character.id, 42);
      expect((renamed.action as UseItemAction).itemName, 'Exact Item');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schedule-change-target')));
      await tester.pumpAndSettle();
      expect(discovery.charactersCalls, 1);
      await save(tester);
      expect(api.updates, 1);
      expect(
        find.text('Choose a character and an offered option before saving.'),
        findsOneWidget,
      );
      final unchanged = (await api.list()).rules.single;
      expect((unchanged.action as UseItemAction).itemName, 'Exact Item');
      await tap(tester, const Key('schedule-character-42'));
      await tap(tester, const Key('schedule-item-Other Item'));
      await save(tester);
      final after = (await api.list()).rules.single;
      expect((after.action as UseItemAction).itemName, 'Other Item');
      expect((after.action as UseItemAction).character.id, 42);
      expect(after.id, before.id);
      expect(after.notificationId, before.notificationId);
      expect(after.nextDueUtc, before.nextDueUtc);
    },
  );

  testWidgets('cancel leaves a configured game rule unchanged', (tester) async {
    final api = FakeSchedulerApi();
    final before = (await api.create(
      intervalDraft(savedItem()),
      id: 'existing',
    )).rules.single;
    final raw = api.store.raw;
    await pumpLocalized(
      tester,
      SchedulerEditor(
        api: api,
        discovery: Discovery(),
        rule: before,
        ensurePermission: () async => true,
      ),
    );
    await field(tester, 'schedule-name', 'unsaved');
    await tester.ensureVisible(find.byKey(const Key('schedule-cancel')));
    await tester.tap(find.byKey(const Key('schedule-cancel')));
    await tester.pumpAndSettle();
    expect(api.store.raw, raw);
    expect((await api.list()).rules.single.name, before.name);
  });

  testWidgets('cards show service, character, effect and truthful result', (
    tester,
  ) async {
    final api = FakeSchedulerApi();
    final created = await api.create(
      intervalDraft(savedItem(), name: 'Morning'),
      id: 'item-rule',
    );
    final item = created.rules.single.copyWith(
      lastResult: ScheduleResult(
        status: ScheduleResultStatus.confirmed,
        atUtc: DateTime.utc(2026, 10, 4, 12),
      ),
    );
    api.refreshedSnapshot = SchedulerSnapshot(
      nextSequence: created.nextSequence,
      rules: [item],
    );
    await pumpLocalized(
      tester,
      SchedulerScreen(api: api, platform: FakeBackgroundPlatform()),
    );
    expect(
      find.text('Use item for Saved Character: Exact Item'),
      findsOneWidget,
    );
    expect(find.text('Game action confirmed'), findsOneWidget);
    expect(find.textContaining('Next: '), findsOneWidget);
  });

  testWidgets('Portuguese cards name the crew bonus and the truthful result', (
    tester,
  ) async {
    final api = FakeSchedulerApi();
    final crew = (await api.create(
      intervalDraft(
        PayCrewAction(
          boundUsername: 'bound',
          character: GameCharacter(id: 42, name: 'Saved Character'),
          artistId: 77,
          artistName: 'Saved Band',
          bonusLevel: 14,
          maxCostMinor: 225000,
        ),
        name: 'Band',
      ),
      id: 'crew-rule',
    )).rules.singleWhere((rule) => rule.id == 'crew-rule').copyWith(
      lastResult: ScheduleResult(
        status: ScheduleResultStatus.unavailable,
        atUtc: DateTime.utc(2026, 10, 4, 12),
      ),
    );
    api.refreshedSnapshot = SchedulerSnapshot(
      nextSequence: 3,
      rules: [crew],
    );
    await pumpLocalized(
      tester,
      SchedulerScreen(api: api, platform: FakeBackgroundPlatform()),
      startLocale: const Locale('pt'),
    );
    expect(
      find.text('Pagar equipe para Saved Character: Saved Band bônus 14'),
      findsOneWidget,
    );
    expect(
      find.text('Ação indisponível; aguardando próxima ocorrência'),
      findsOneWidget,
    );
    expect(find.textContaining('Próxima: '), findsOneWidget);
  });
}
