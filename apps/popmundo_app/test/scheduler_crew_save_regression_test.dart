import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/scheduler_editor.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'fake_scheduler_api.dart';
import 'localization_helpers.dart';
import 'scheduler_editor_test.dart' show field, save;
import 'scheduler_game_editor_test.dart' show Discovery, tap;

class CrewDiscovery extends Discovery {
  @override
  Future<GameCrewOptions> discoverCrew({
    required String boundUsername,
    required GameCharacter character,
  }) async => GameCrewOptions(
    artistId: 77,
    artistName: 'Saved Band',
    bonuses: const [],
  );
}

class PendingDiscovery extends CrewDiscovery {
  final catalog = Completer<GameCharacterCatalog>();
  final crew = Completer<GameCrewOptions>();
  @override
  Future<GameCharacterCatalog> discoverCharacters() => catalog.future;
  @override
  Future<GameCrewOptions> discoverCrew({
    required String boundUsername,
    required GameCharacter character,
  }) => crew.future;
}

void main() {
  testWidgets('future maximum crew rule edits offline without adding a cap', (
    tester,
  ) async {
    final api = FakeSchedulerApi();
    final original = (await api.create(
      ScheduleDraft(
        name: 'Future maximum',
        recurrence: IntervalRecurrence(
          quantity: 7,
          unit: IntervalUnit.days,
          anchorUtc: DateTime.utc(2026, 10, 6),
        ),
        action: PayCrewAction(
          boundUsername: 'bound',
          character: GameCharacter(id: 42, name: 'Saved Character'),
          artistId: 77,
          artistName: 'Saved Band',
          bonusLevel: 20,
        ),
      ),
      id: 'future-crew',
    )).rules.single;
    final discovery = Discovery();
    await pumpLocalized(
      tester,
      SchedulerEditor(
        api: api,
        discovery: discovery,
        rule: original,
        ensurePermission: () async => true,
      ),
    );
    expect(
      find.text(
        'Each eligible occurrence distributes cash bonus 20 to Saved Band at the cost offered by the game at execution.',
      ),
      findsOneWidget,
    );
    await field(tester, 'schedule-name', 'Renamed future');
    await save(tester);
    final saved = SchedulerSnapshot.decode(api.store.raw!).rules.single;
    expect(saved.id, original.id);
    expect(saved.notificationId, original.notificationId);
    expect(saved.nextDueUtc, original.nextDueUtc);
    expect(saved.action.toJson(), original.action.toJson());
    expect((saved.action as PayCrewAction).maxCostMinor, isNull);
    expect(discovery.charactersCalls, 0);
    expect(discovery.crewCalls, 0);
  });
  testWidgets('available default maximum saves its discovered quote cap', (
    tester,
  ) async {
    final api = FakeSchedulerApi();
    await pumpLocalized(
      tester,
      SchedulerEditor(
        api: api,
        discovery: Discovery(),
        ensurePermission: () async => true,
      ),
    );
    await field(tester, 'schedule-name', 'Maximum crew');
    await tap(tester, const Key('schedule-service-crew'));
    await tap(tester, const Key('schedule-character-42'));
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('schedule-bonus-20')))
          .selected,
      true,
    );
    await save(tester);
    final action =
        SchedulerSnapshot.decode(api.store.raw!).rules.single.action
            as PayCrewAction;
    expect(action.boundUsername, 'bound');
    expect(action.character.id, 42);
    expect(action.character.name, 'Saved Character');
    expect(action.artistId, 77);
    expect(action.artistName, 'Saved Band');
    expect(action.bonusLevel, 20);
    expect(action.maxCostMinor, 900000);
  });
  for (final locale in ['en', 'pt']) {
    testWidgets('unavailable crew schedules future maximum bonus in $locale', (
      tester,
    ) async {
      final api = FakeSchedulerApi();
      await pumpLocalized(
        tester,
        SchedulerEditor(
          api: api,
          discovery: CrewDiscovery(),
          ensurePermission: () async => true,
        ),
        startLocale: Locale(locale),
      );
      await field(tester, 'schedule-name', 'Crew rule');
      await tap(tester, const Key('schedule-service-crew'));
      await tap(tester, const Key('schedule-character-42'));
      final message = locale == 'pt'
          ? 'Bônus indisponível no jogo agora. Você pode agendar o bônus máximo (20) para uma próxima ocorrência; o custo será definido pelo jogo na execução.'
          : 'No crew bonus is available in the game now. You can schedule the maximum bonus (20) for a future occurrence; the game will set its cost at execution.';
      expect(
        find.byKey(const Key('schedule-crew-unavailable')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('schedule-crew-unavailable')),
      );
      await tester.pumpAndSettle();
      expect(find.text(message).hitTestable(), findsOneWidget);
      expect(find.textContaining('Saved Band'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('schedule-save')))
            .onPressed,
        isNotNull,
      );
      await save(tester);
      final saved = SchedulerSnapshot.decode(api.store.raw!).rules.single;
      final action = saved.action as PayCrewAction;
      expect(saved.name, 'Crew rule');
      expect(action.boundUsername, 'bound');
      expect(action.character.id, 42);
      expect(action.character.name, 'Saved Character');
      expect(action.artistId, 77);
      expect(action.artistName, 'Saved Band');
      expect(action.bonusLevel, 20);
      expect(action.maxCostMinor, isNull);
    });
  }

  testWidgets(
    'discovery shows progress for characters and crew then unlocks save',
    (tester) async {
      final api = FakeSchedulerApi();
      final discovery = PendingDiscovery();
      await pumpLocalized(
        tester,
        SchedulerEditor(
          api: api,
          discovery: discovery,
          ensurePermission: () async => true,
        ),
      );
      await field(tester, 'schedule-name', 'Loading rule');
      await tester.ensureVisible(
        find.byKey(const Key('schedule-service-crew')),
      );
      await tester.tap(find.byKey(const Key('schedule-service-crew')));
      await tester.pump();
      expect(find.byKey(const Key('schedule-options-loading')), findsOneWidget);
      expect(find.text('Loading game options…'), findsNWidgets(2));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('schedule-save')))
            .onPressed,
        isNull,
      );
      discovery.catalog.complete(
        GameCharacterCatalog(
          username: 'bound',
          characters: [discovery.character],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('schedule-options-loading')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('schedule-character-42')),
      );
      await tester.tap(find.byKey(const Key('schedule-character-42')));
      await tester.pump();
      expect(find.byKey(const Key('schedule-options-loading')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('schedule-save')))
            .onPressed,
        isNull,
      );
      discovery.crew.complete(
        GameCrewOptions(
          artistId: 77,
          artistName: 'Saved Band',
          bonuses: const [],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('schedule-options-loading')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('schedule-save')))
            .onPressed,
        isNotNull,
      );
      await save(tester);
      final action =
          SchedulerSnapshot.decode(api.store.raw!).rules.single.action
              as PayCrewAction;
      expect(action.character.id, 42);
      expect(action.artistId, 77);
      expect(action.bonusLevel, 20);
      expect(action.maxCostMinor, isNull);
    },
  );

  testWidgets('crew save reveals invalid fields above the selected bonus', (
    tester,
  ) async {
    final api = FakeSchedulerApi();
    await pumpLocalized(
      tester,
      SchedulerEditor(
        api: api,
        discovery: Discovery(),
        ensurePermission: () async => true,
      ),
    );
    await tap(tester, const Key('schedule-service-crew'));
    await tap(tester, const Key('schedule-character-42'));
    await tap(tester, const Key('schedule-bonus-14'));
    expect(find.byKey(const Key('schedule-name')).hitTestable(), findsNothing);
    await save(tester);
    expect(
      find.text('Required: 1–80 characters').hitTestable(),
      findsOneWidget,
    );
    expect(api.creates, 0);
    expect(api.store.raw, isNull);
    await field(tester, 'schedule-name', 'Crew after validation');
    await save(tester);
    final saved = SchedulerSnapshot.decode(api.store.raw!).rules.single;
    expect(saved.name, 'Crew after validation');
    expect((saved.action as PayCrewAction).character.id, 42);
    expect((saved.action as PayCrewAction).bonusLevel, 14);
    expect((saved.action as PayCrewAction).maxCostMinor, 225000);
  });
}
