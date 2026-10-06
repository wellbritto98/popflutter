import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/scheduler_environment.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('secondary engine creates enabled rule using application-context permission without Activity', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    const foreground = MethodChannel('flutter_foreground_task/methods');
    const notifications = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    const zone = MethodChannel('flutter_timezone');
    final foregroundCalls = <String>[];
    final notificationCalls = <String>[];
    var permitted = true;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(foreground, (call) async {
      foregroundCalls.add(call.method);
      if (call.method == 'checkNotificationPermission' ||
          call.method == 'requestNotificationPermission') {
        throw PlatformException(code: 'ActivityNotAttachedException');
      }
      return true;
    });
    messenger.setMockMethodCallHandler(notifications, (call) async {
      notificationCalls.add(call.method);
      if (call.method == 'areNotificationsEnabled') return permitted;
      return true;
    });
    messenger.setMockMethodCallHandler(zone, (_) async => 'America/Sao_Paulo');
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(foreground, null);
      messenger.setMockMethodCallHandler(notifications, null);
      messenger.setMockMethodCallHandler(zone, null);
    });
    final runner = await createSchedulerRunner();
    addTearDown(runner.dispose);
    await runner.start();
    Map<String, Object?> request(String id) => {
      'type': 'scheduler.request',
      'requestId': id,
      'command': 'create',
      'id': id,
      'draft': {
        'name': 'Saved',
        'enabled': true,
        'recurrence': IntervalRecurrence(
          quantity: 9999,
          anchorUtc: DateTime.now().toUtc(),
        ).toJson(),
        'action': LocalNotificationAction(
          title: 'Exact title',
          body: 'Exact body',
        ).toJson(),
      },
    };
    await runner.receive(request('stable'));
    expect(runner.errorCode, isNull);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(SchedulerSnapshot.storageKey)!;
    final saved = SchedulerSnapshot.decode(raw).rules.single;
    expect(saved.id, 'stable');
    expect(saved.notificationId, -1);
    expect(saved.enabled, true);
    expect((saved.action as LocalNotificationAction).title, 'Exact title');
    expect((saved.action as LocalNotificationAction).body, 'Exact body');
    expect(notificationCalls, ['areNotificationsEnabled']);
    expect(foregroundCalls, isNot(contains('checkNotificationPermission')));
    expect(foregroundCalls, isNot(contains('requestNotificationPermission')));
    permitted = false;
    await runner.receive(request('denied'));
    expect(runner.errorCode, 'permissionDenied');
    expect(prefs.getString(SchedulerSnapshot.storageKey), raw);
  });
}
