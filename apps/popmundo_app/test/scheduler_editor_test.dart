import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/scheduler_editor.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'fake_scheduler_api.dart';
import 'localization_helpers.dart';

Future<void> field(WidgetTester tester, String key, String value) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), value);
}

Future<void> fill(WidgetTester tester) async {
  await field(tester, 'schedule-name', ' Reminder ');
  await field(tester, 'schedule-title', ' Saved title ');
  await field(tester, 'schedule-body', ' Saved body ');
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('schedule-save')));
  await tester.tap(find.byKey(const Key('schedule-save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'supplementary Unicode at trimmed UTF-16 limits saves exact payload',
    (tester) async {
      final api = FakeSchedulerApi();
      SchedulerSnapshot? saved;
      final name = '😀' * 40;
      final title = '😀' * 60;
      final body = '😀' * 500;
      await pumpLocalized(
        tester,
        SchedulerEditor(
          api: api,
          ensurePermission: () async => true,
          onSaved: (snapshot) => saved = snapshot,
        ),
      );
      await field(tester, 'schedule-name', ' \t$name\t ');
      await field(tester, 'schedule-title', ' \t$title\t ');
      await field(tester, 'schedule-body', ' \t$body\t ');
      await save(tester);

      expect(api.creates, 1);
      expect(api.updates, 0);
      expect(saved, isNotNull);
      final authoritative = saved!.rules.single;
      expect(authoritative.name, name);
      expect(authoritative.name.length, 80);
      expect((authoritative.action as LocalNotificationAction).title, title);
      expect(
        (authoritative.action as LocalNotificationAction).title.length,
        120,
      );
      expect((authoritative.action as LocalNotificationAction).body, body);
      expect(
        (authoritative.action as LocalNotificationAction).body.length,
        1000,
      );
      expect(api.store.raw, saved!.encode());
      final persisted = SchedulerSnapshot.decode(api.store.raw!).rules.single;
      expect(persisted.name, name);
      expect((persisted.action as LocalNotificationAction).title, title);
      expect((persisted.action as LocalNotificationAction).body, body);
    },
  );
  testWidgets(
    'supplementary Unicode beyond UTF-16 limits shows field errors without saving',
    (tester) async {
      final api = FakeSchedulerApi();
      final original = (await api.create(
        ScheduleDraft(
          name: 'original',
          recurrence: IntervalRecurrence(
            quantity: 1,
            unit: IntervalUnit.minutes,
            anchorUtc: DateTime.utc(2026, 10, 4, 12),
          ),
          action: LocalNotificationAction(
            title: 'original title',
            body: 'body',
          ),
        ),
        id: 'existing',
      )).rules.single;
      final raw = api.store.raw;
      final creates = api.creates;
      SchedulerSnapshot? saved;
      await pumpLocalized(
        tester,
        SchedulerEditor(
          api: api,
          rule: original,
          ensurePermission: () async => true,
          onSaved: (snapshot) => saved = snapshot,
        ),
      );
      final inputs = {
        'schedule-name': ' \t${'😀' * 41}\t ',
        'schedule-title': ' \t${'😀' * 61}\t ',
        'schedule-body': ' \t${'😀' * 501}\t ',
      };
      for (final input in inputs.entries) {
        await field(tester, input.key, input.value);
      }
      await save(tester);

      final errors = {
        'schedule-name': 'Required: 1–80 characters',
        'schedule-title': 'Required: 1–120 characters',
        'schedule-body': 'Required: 1–1000 characters',
      };
      for (final input in inputs.entries) {
        final formField = find.byKey(Key(input.key));
        await tester.ensureVisible(formField);
        await tester.pumpAndSettle();
        expect(
          find
              .descendant(
                of: formField,
                matching: find.text(errors[input.key]!),
              )
              .hitTestable(),
          findsOneWidget,
          reason: '${input.key} must display its UTF-16 length error',
        );
        expect(
          tester.widget<TextFormField>(formField).controller!.text,
          input.value,
          reason: '${input.key} must retain the complete rejected input',
        );
      }
      expect(saved, isNull);
      expect(api.creates, creates);
      expect(api.updates, 0);
      expect(api.savedDraft!.name, 'original');
      expect(api.store.raw, raw);
    },
  );
  testWidgets('Portuguese form labels and validation resolve catalog strings', (
    tester,
  ) async {
    final api = FakeSchedulerApi();
    await pumpLocalized(
      tester,
      SchedulerEditor(api: api, ensurePermission: () async => true),
      startLocale: const Locale('pt'),
    );
    expect(find.text('Criar agendamento'), findsOneWidget);
    expect(find.text('Notificação local'), findsOneWidget);
    expect(find.text('Usar item'), findsOneWidget);
    expect(find.text('Pagar equipe'), findsOneWidget);
    expect(find.text('Salvar'), findsOneWidget);
    await save(tester);
    expect(find.text('Obrigatório: 1–80 caracteres'), findsOneWidget);
    expect(find.text('Obrigatório: 1–120 caracteres'), findsOneWidget);
    expect(find.text('Obrigatório: 1–1000 caracteres'), findsOneWidget);
    expect(api.creates, 0);
  });
  testWidgets(
    'days unit persists elapsed 24h quantity and weekly picker uses 24h',
    (tester) async {
      final api = FakeSchedulerApi();
      await pumpLocalized(
        tester,
        SchedulerEditor(api: api, ensurePermission: () async => true),
      );
      await fill(tester);
      await field(tester, 'schedule-quantity', '2');
      await tester.ensureVisible(find.byKey(const Key('schedule-unit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schedule-unit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('day(s)').last);
      await tester.pumpAndSettle();
      await save(tester);
      final rule = (await api.list()).rules.single;
      expect((rule.recurrence as IntervalRecurrence).unit, IntervalUnit.days);
      expect((rule.recurrence as IntervalRecurrence).quantity, 2);
      expect(rule.nextDueUtc, DateTime.utc(2026, 10, 6, 12));
      await tester.ensureVisible(find.byKey(const Key('schedule-weekly')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schedule-weekly')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('schedule-time')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schedule-time')));
      await tester.pumpAndSettle();
      expect(
        MediaQuery.of(tester.element(find.byType(TimePickerDialog)))
            .alwaysUse24HourFormat,
        true,
      );
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'valid save uses default minute and authoritative response; pending save disabled',
    (tester) async {
      final api = FakeSchedulerApi()..saveBlock = Completer<void>();
      SchedulerSnapshot? saved;
      await pumpLocalized(
        tester,
        SchedulerEditor(
          api: api,
          ensurePermission: () async => true,
          onSaved: (value) => saved = value,
        ),
      );
      await fill(tester);
      await tester.ensureVisible(find.byKey(const Key('schedule-save')));
      await tester.tap(find.byKey(const Key('schedule-save')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('schedule-save')))
            .onPressed,
        isNull,
      );
      expect(saved, isNull);
      api.saveBlock!.complete();
      await tester.pumpAndSettle();
      final rule = saved!.rules.single;
      expect(rule.name, 'Reminder');
      expect((rule.action as LocalNotificationAction).title, 'Saved title');
      expect((rule.action as LocalNotificationAction).body, 'Saved body');
      expect((rule.recurrence as IntervalRecurrence).quantity, 1);
      expect(
        (rule.recurrence as IntervalRecurrence).unit,
        IntervalUnit.minutes,
      );
      expect(SchedulerSnapshot.decode(api.store.raw!).rules.single.id, rule.id);
    },
  );
  testWidgets('invalid and overlong fields keep saved catalog untouched', (
    tester,
  ) async {
    final api = FakeSchedulerApi();
    await pumpLocalized(
      tester,
      SchedulerEditor(api: api, ensurePermission: () async => true),
    );
    await save(tester);
    expect(find.text('Required: 1–80 characters'), findsOneWidget);
    expect(api.creates, 0);
    await fill(tester);
    for (final value in ['0', '10000', '1.5']) {
      await field(tester, 'schedule-quantity', value);
      await save(tester);
      expect(find.text('Use a whole number from 1 to 9999'), findsOneWidget);
      expect(api.creates, 0);
    }
    await field(tester, 'schedule-quantity', '1');
    await field(tester, 'schedule-name', 'x' * 81);
    await field(tester, 'schedule-title', 'x' * 121);
    await field(tester, 'schedule-body', 'x' * 1001);
    await save(tester);
    expect(find.text('Required: 1–80 characters'), findsOneWidget);
    expect(find.text('Required: 1–120 characters'), findsOneWidget);
    expect(find.text('Required: 1–1000 characters'), findsOneWidget);
    expect(api.store.raw, isNull);
  });
  testWidgets(
    'weekly validates selected days and saves intended weekdays/local time',
    (tester) async {
      final api = FakeSchedulerApi();
      await pumpLocalized(
        tester,
        SchedulerEditor(api: api, ensurePermission: () async => true),
      );
      await fill(tester);
      await tester.ensureVisible(find.byKey(const Key('schedule-weekly')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schedule-weekly')));
      await tester.pumpAndSettle();
      await save(tester);
      expect(find.text('Choose at least one weekday'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('schedule-day-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schedule-day-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schedule-day-4')));
      await save(tester);
      final recurrence =
          (await api.list()).rules.single.recurrence as WeeklyRecurrence;
      expect(recurrence.weekdays, {1, 4});
      expect(recurrence.hour, 9);
      expect(recurrence.minute, 0);
    },
  );
  testWidgets('denial and command errors retain input without activation', (
    tester,
  ) async {
    final api = FakeSchedulerApi();
    var permission = false;
    await pumpLocalized(
      tester,
      SchedulerEditor(api: api, ensurePermission: () async => permission),
    );
    await fill(tester);
    await save(tester);
    expect(api.creates, 0);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('schedule-name')))
          .controller!
          .text,
      ' Reminder ',
    );
    expect(
      find.text('Allow notifications to enable this schedule.'),
      findsOneWidget,
    );
    permission = true;
    api.failure = 'writeFailed';
    await save(tester);
    expect(
      find.text(
        'Could not save. Your changes are kept; check the saved list before retrying.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('schedule-title')))
          .controller!
          .text,
      ' Saved title ',
    );
    expect(api.store.raw, isNull);
  });
  testWidgets(
    'lost create reply refreshes and adopts stable id; failed refresh blocks resubmit',
    (tester) async {
      final api = FakeSchedulerApi()
        ..loseCreateReply = true
        ..failList = true;
      await pumpLocalized(
        tester,
        SchedulerEditor(api: api, ensurePermission: () async => true),
      );
      await fill(tester);
      await save(tester);
      expect(api.creates, 1);
      final id = api.createdId;
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('schedule-save')))
            .onPressed,
        isNull,
      );
      expect(find.byKey(const Key('schedule-editor')), findsOneWidget);
      api.failList = false;
      await tester.ensureVisible(find.byKey(const Key('schedule-reread')));
      await tester.tap(find.byKey(const Key('schedule-reread')));
      await tester.pumpAndSettle();
      await save(tester);
      expect(api.creates, 1);
      expect(api.updates, 1);
      expect((await api.list()).rules.single.id, id);
      expect((await api.list()).nextSequence, 2);
    },
  );
  testWidgets(
    'text edit preserves anchor/id and cancel leaves persisted rule unchanged',
    (tester) async {
      final api = FakeSchedulerApi();
      final draft = ScheduleDraft(
        name: 'original',
        recurrence: IntervalRecurrence(
          quantity: 10,
          unit: IntervalUnit.seconds,
          anchorUtc: DateTime.utc(2026),
        ),
        action: LocalNotificationAction(title: 't', body: 'b'),
      );
      final before = (await api.create(draft, id: 'existing')).rules.single;
      await pumpLocalized(
        tester,
        SchedulerEditor(
          api: api,
          rule: before,
          ensurePermission: () async => true,
        ),
      );
      await field(tester, 'schedule-name', 'edited');
      await save(tester);
      final after = (await api.list()).rules.single;
      expect(after.notificationId, before.notificationId);
      expect(
        (after.recurrence as IntervalRecurrence).anchorUtc,
        (before.recurrence as IntervalRecurrence).anchorUtc,
      );
      expect(after.nextDueUtc, before.nextDueUtc);
      final raw = api.store.raw;
      await field(tester, 'schedule-name', 'unsaved');
      await tester.ensureVisible(find.byKey(const Key('schedule-cancel')));
      await tester.tap(find.byKey(const Key('schedule-cancel')));
      await tester.pumpAndSettle();
      expect(api.store.raw, raw);
    },
  );
}
