import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/scheduler_environment.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('service composition accepts native GMT alias and persists next weekly local 09:00 as exact UTC', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    const foreground = MethodChannel('flutter_foreground_task/methods');
    const notifications = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    const zone = MethodChannel('flutter_timezone');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(foreground, (_) async => true);
    messenger.setMockMethodCallHandler(notifications, (call) async {
      return true;
    });
    messenger.setMockMethodCallHandler(
      zone,
      (_) async => {
        'identifier': 'GMT',
        'localizedName': 'Greenwich Mean Time',
        'locale': 'en_US',
      },
    );
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(foreground, null);
      messenger.setMockMethodCallHandler(notifications, null);
      messenger.setMockMethodCallHandler(zone, null);
    });
    final runner = await createSchedulerRunner();
    addTearDown(runner.dispose);
    await runner.start();
    final now = DateTime.now().toUtc();
    // Device GMT is UTC+00:00: tomorrow's local 09:00 is this exact UTC date.
    final expected = DateTime.utc(now.year, now.month, now.day + 1, 9);
    await runner.receive({
      'type': 'scheduler.request',
      'requestId': 'weekly',
      'command': 'create',
      'id': 'weekly-gmt',
      'draft': {
        'name': 'Morning',
        'enabled': true,
        'recurrence': WeeklyRecurrence(
          weekdays: {expected.weekday},
          hour: 9,
          minute: 0,
        ).toJson(),
        'action': LocalNotificationAction(
          title: 'Saved',
          body: 'Body',
        ).toJson(),
      },
    });
    expect(runner.errorCode, isNull);
    final raw = (await SharedPreferences.getInstance()).getString(
      SchedulerSnapshot.storageKey,
    )!;
    final rule = SchedulerSnapshot.decode(raw).rules.single;
    expect(rule.zoneId, 'GMT');
    expect(rule.nextDueUtc, expected);
    expect(rule.enabled, true);
    expect(rule.lastResult.status, ScheduleResultStatus.neverExecuted);
    expect(rule.lastResult.errorCode, isNull);
  });
}
