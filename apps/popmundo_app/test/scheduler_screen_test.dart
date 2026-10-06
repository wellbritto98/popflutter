import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/scheduler_screen.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'fake_scheduler_api.dart';
import 'fake_background_platform.dart';
import 'localization_helpers.dart';

String nextText(DateTime value) =>
    ['Next: ', value.toLocal().toString().split('.').first].join();

class StatusFailure extends FakeBackgroundPlatform {
  @override
  Future<bool> isNotificationGranted() async => throw StateError('status');
}

void main() {
  testWidgets(
    'visible catalog reads coalesce while pending and pause when app inactive',
    (tester) async {
      final api = FakeSchedulerApi();
      await pumpLocalized(
        tester,
        SchedulerScreen(api: api, platform: FakeBackgroundPlatform()),
      );
      api.listBlock = Completer<void>();
      final before = api.lists;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 15));
      expect(api.lists, before + 1);
      api.listBlock!.complete();
      await tester.pumpAndSettle();
      api.listBlock = null;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final paused = api.lists;
      await tester.pump(const Duration(seconds: 10));
      expect(api.lists, paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(api.lists, paused + 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'visible list refreshes authoritative submission/failure/time without manual action',
    (tester) async {
      final api = FakeSchedulerApi();
      final initial = await api.create(
        ScheduleDraft(
          name: 'Fresh',
          recurrence: IntervalRecurrence(
            quantity: 10,
            unit: IntervalUnit.seconds,
            anchorUtc: DateTime.utc(2026),
          ),
          action: LocalNotificationAction(title: 't', body: 'b'),
        ),
        id: 'a',
      );
      await pumpLocalized(
        tester,
        SchedulerScreen(api: api, platform: FakeBackgroundPlatform()),
      );
      final at = DateTime.utc(2026, 10, 4, 12, 0, 10);
      api.refreshedSnapshot = SchedulerSnapshot(
        nextSequence: 2,
        rules: [
          initial.rules.single.copyWith(
            nextDueUtc: DateTime.utc(2026, 10, 4, 12, 0, 20),
            lastResult: ScheduleResult(
              status: ScheduleResultStatus.submitted,
              atUtc: at,
            ),
          ),
        ],
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Submitted to Android'), findsOneWidget);
      expect(
        find.text(nextText(DateTime.utc(2026, 10, 4, 12, 0, 20))),
        findsOneWidget,
      );
      expect(
        find.text(at.toLocal().toString().split('.').first),
        findsOneWidget,
      );
      api.refreshedSnapshot = SchedulerSnapshot(
        nextSequence: 2,
        rules: [
          initial.rules.single.copyWith(
            lastResult: ScheduleResult(
              status: ScheduleResultStatus.failed,
              atUtc: at,
              errorCode: 'notificationInitializationFailed',
            ),
          ),
        ],
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        find.text('Failed: Notification service could not initialize.'),
        findsOneWidget,
      );
      expect(
        find.text(at.toLocal().toString().split('.').first),
        findsOneWidget,
      );
      final reads = api.lists;
      await tester.tap(find.byKey(const Key('schedule-edit-a')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      expect(api.lists, reads);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('empty list, translated PT and iOS unavailable explanation', (
    tester,
  ) async {
    final api = FakeSchedulerApi();
    await pumpLocalized(
      tester,
      SchedulerScreen(api: api, platform: FakeBackgroundPlatform()),
    );
    expect(find.text('No schedules yet'), findsOneWidget);
    expect(find.byKey(const Key('schedule-add')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await pumpLocalized(
      tester,
      SchedulerScreen(
        api: api,
        platform: FakeBackgroundPlatform(isAndroid: false, isIOS: true),
      ),
      startLocale: const Locale('pt'),
    );
    expect(find.text('Agendamentos'), findsOneWidget);
    expect(
      find.text(
        'Os agendamentos contínuos estão disponíveis apenas no Android.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('schedule-add')), findsNothing);
  });
  testWidgets(
    'list shows exact recurrence/next/latest; pause and confirmed delete are authoritative',
    (tester) async {
      final api = FakeSchedulerApi();
      await api.create(
        ScheduleDraft(
          name: 'Reminder',
          recurrence: IntervalRecurrence(
            quantity: 10,
            unit: IntervalUnit.seconds,
            anchorUtc: DateTime.utc(2026),
          ),
          action: LocalNotificationAction(title: 't', body: 'b'),
        ),
        id: 'a',
      );
      await pumpLocalized(
        tester,
        SchedulerScreen(
          api: api,
          platform: FakeBackgroundPlatform(
            notificationGranted: true,
            ignoringBattery: true,
            runningService: true,
          ),
        ),
      );
      expect(find.text('Reminder'), findsOneWidget);
      expect(find.text('Every 10 second(s)'), findsOneWidget);
      expect(
        find.text(nextText(DateTime.utc(2026, 10, 4, 12, 0, 10))),
        findsOneWidget,
      );
      expect(find.text('Never executed'), findsOneWidget);
      await tester.tap(find.byKey(const Key('schedule-toggle-a')));
      await tester.pumpAndSettle();
      expect((await api.list()).rules.single.enabled, false);
      expect(find.text('Paused'), findsOneWidget);
      await tester.tap(find.byKey(const Key('schedule-delete-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schedule-delete-cancel')));
      await tester.pumpAndSettle();
      expect((await api.list()).rules, hasLength(1));
      await tester.tap(find.byKey(const Key('schedule-delete-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('schedule-delete-confirm')));
      await tester.pumpAndSettle();
      expect((await api.list()).rules, isEmpty);
      expect(find.text('No schedules yet'), findsOneWidget);
    },
  );
  testWidgets(
    'permission status is actionable and lookup failure does not hide catalog',
    (tester) async {
      final api = FakeSchedulerApi();
      final platform = FakeBackgroundPlatform(runningService: true);
      await pumpLocalized(
        tester,
        SchedulerScreen(api: api, platform: platform),
      );
      expect(find.text('Notifications: denied'), findsOneWidget);
      expect(find.text('Background: battery optimized'), findsOneWidget);
      expect(find.text('Service: running'), findsOneWidget);
      await tester.tap(find.byKey(const Key('schedule-permissions')));
      await tester.pumpAndSettle();
      expect(platform.notificationRequestCount, 1);
      expect(platform.batteryRequestCount, 1);
      expect(find.text('Notifications: allowed'), findsOneWidget);
      await api.create(
        ScheduleDraft(
          name: 'Readable',
          recurrence: IntervalRecurrence(anchorUtc: DateTime.utc(2026)),
          action: LocalNotificationAction(title: 't', body: 'b'),
        ),
        id: 'a',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await pumpLocalized(
        tester,
        SchedulerScreen(api: api, platform: StatusFailure()),
      );
      expect(find.text('Readable'), findsOneWidget);
      expect(
        find.text('Could not read permission or background status. Try again.'),
        findsOneWidget,
      );
    },
  );
}
