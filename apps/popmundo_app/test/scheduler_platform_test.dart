import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:popmundo_app/background/flutter_foreground_task_platform.dart';
import 'package:popmundo_app/notifications/local_notifications_service.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('empty, paused and corrupt catalogs disable boot without breaking session initialization', () async {
    final paused = SchedulerSnapshot(
      nextSequence: 2,
      rules: [
        ScheduledRule(
          id: 'x',
          revision: 1,
          notificationId: -1,
          name: 'x',
          enabled: false,
          recurrence: IntervalRecurrence(anchorUtc: DateTime.utc(2026)),
          action: LocalNotificationAction(title: 't', body: 'b'),
        ),
      ],
    ).encode();
    for (final raw in <String?>[
      null,
      SchedulerSnapshot().encode(),
      paused,
      'bad-blob',
    ]) {
      SharedPreferences.setMockInitialValues({
        SchedulerSnapshot.storageKey: ?raw,
      });
      await FlutterForegroundTaskPlatform().initService();
      expect(FlutterForegroundTask.isInitialized, true);
      expect(FlutterForegroundTask.foregroundTaskOptions!.autoRunOnBoot, false);
      expect(
        FlutterForegroundTask.foregroundTaskOptions!.autoRunOnMyPackageReplaced,
        false,
      );
      expect(FlutterForegroundTask.foregroundTaskOptions!.allowWakeLock, true);
      expect(FlutterForegroundTask.foregroundTaskOptions!.stopWithTask, false);
      expect(
        (await SharedPreferences.getInstance()).getString(
          SchedulerSnapshot.storageKey,
        ),
        raw,
      );
    }
  });
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'fresh catalog drives complete init flags and preserves runtime options',
    () async {
      SharedPreferences.setMockInitialValues({
        SchedulerSnapshot.storageKey: SchedulerSnapshot(
          nextSequence: 2,
          rules: [
            ScheduledRule(
              id: 'x',
              revision: 1,
              notificationId: -1,
              name: 'x',
              enabled: true,
              recurrence: IntervalRecurrence(anchorUtc: DateTime.utc(2026)),
              action: LocalNotificationAction(title: 't', body: 'b'),
            ),
          ],
        ).encode(),
      });
      await FlutterForegroundTaskPlatform().initService();
      final options = FlutterForegroundTask.foregroundTaskOptions!;
      expect(options.autoRunOnBoot, true);
      expect(options.autoRunOnMyPackageReplaced, true);
      expect(options.allowWakeLock, true);
      expect(options.stopWithTask, false);
      expect(
        options.eventAction.toJson(),
        ForegroundTaskEventAction.repeat(5000).toJson(),
      );
    },
  );
  test('strict action submits saved negative id/title/body; false init and denied permission fail', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final calls = <MethodCall>[];
    var initialized = false;
    var permitted = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize') return initialized;
          if (call.method == 'areNotificationsEnabled') return permitted;
          return null;
        });
    final service = LocalNotificationsService();
    await expectLater(
      service.showScheduledNotification(
        id: -5,
        title: 'Saved',
        body: 'Message',
      ),
      throwsA(
        isA<SchedulerException>().having(
          (e) => e.code,
          'code',
          'notificationInitializationFailed',
        ),
      ),
    );
    expect(calls.where((c) => c.method == 'show'), isEmpty);
    initialized = true;
    permitted = false;
    await expectLater(
      service.showScheduledNotification(
        id: -5,
        title: 'Saved',
        body: 'Message',
      ),
      throwsA(
        isA<SchedulerException>().having(
          (e) => e.code,
          'code',
          'permissionDenied',
        ),
      ),
    );
    permitted = true;
    await service.showScheduledNotification(
      id: -5,
      title: 'Saved',
      body: 'Message',
    );
    final payload = calls.last.arguments as Map;
    expect(payload['id'], -5);
    expect(payload['title'], 'Saved');
    expect(payload['body'], 'Message');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'areNotificationsEnabled') return true;
          throw PlatformException(code: 'submission');
        });
    await expectLater(
      service.showScheduledNotification(
        id: -5,
        title: 'Saved',
        body: 'Message',
      ),
      throwsA(isA<PlatformException>()),
    );
  });
}
