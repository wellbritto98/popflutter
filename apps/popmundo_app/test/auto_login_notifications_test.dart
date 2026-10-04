import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/autologin/auto_login_notifications.dart';
import 'package:popmundo_app/notifications/notification_service.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'localization_helpers.dart';

class _Notification {
  const _Notification(this.id, this.title, this.body, this.payload);
  final int id;
  final String title;
  final String body;
  final String? payload;
}

class _Notifications implements NotificationService {
  final shown = <_Notification>[];
  var fail = false;

  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> showTestNotification() async {}
  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (fail) throw StateError('Notification unavailable');
    shown.add(_Notification(id, title, body, payload));
  }
}

void main() {
  for (final locale in const [Locale('en'), Locale('pt')]) {
    testWidgets(
      'background login result is localized in ${locale.languageCode}',
      (tester) async {
        await pumpLocalized(tester, const SizedBox(), startLocale: locale);
        final notifications = _Notifications();
        await notifyAutoLoginResult(
          status: const AutoLoginStatus(
            AutoLoginPhase.done,
            characterName: 'Deon Drinkwater',
          ),
          lifecycle: AppLifecycleState.paused,
          notificationService: notifications,
        );
        expect(notifications.shown, hasLength(1));
        final shown = notifications.shown.single;
        expect(shown.id, 2);
        expect(
          shown.title,
          locale.languageCode == 'pt' ? 'Login automático' : 'Auto Login',
        );
        expect(
          shown.body,
          locale.languageCode == 'pt'
              ? 'Conectado como Deon Drinkwater'
              : 'Signed in as Deon Drinkwater',
        );
        expect(shown.payload, isNull);
      },
    );
  }

  testWidgets('background failure uses the login result tray slot', (
    tester,
  ) async {
    await pumpLocalized(tester, const SizedBox());
    final notifications = _Notifications();
    await notifyAutoLoginResult(
      status: const AutoLoginStatus.failed(AutoLoginFailure.invalidCredentials),
      lifecycle: AppLifecycleState.hidden,
      notificationService: notifications,
    );
    expect(notifications.shown, hasLength(1));
    expect(notifications.shown.single.id, 2);
    expect(notifications.shown.single.title, 'Auto Login');
    expect(
      notifications.shown.single.body,
      'Auto Login failed: check your username and password',
    );
  });

  testWidgets('foreground results and intermediate phases stay in the app', (
    tester,
  ) async {
    await pumpLocalized(tester, const SizedBox());
    final notifications = _Notifications();
    for (final status in const [
      AutoLoginStatus(AutoLoginPhase.done, characterName: 'Deon'),
      AutoLoginStatus.failed(AutoLoginFailure.networkError),
    ]) {
      await notifyAutoLoginResult(
        status: status,
        lifecycle: AppLifecycleState.resumed,
        notificationService: notifications,
      );
    }
    for (final phase in [
      AutoLoginPhase.detected,
      AutoLoginPhase.authenticating,
      AutoLoginPhase.choosingCharacter,
    ]) {
      await notifyAutoLoginResult(
        status: AutoLoginStatus(phase),
        lifecycle: AppLifecycleState.paused,
        notificationService: notifications,
      );
    }
    expect(notifications.shown, isEmpty);
  });

  testWidgets('notification errors leave feedback listener usable', (
    tester,
  ) async {
    await pumpLocalized(tester, const SizedBox());
    final notifications = _Notifications()..fail = true;
    const status = AutoLoginStatus(AutoLoginPhase.done, characterName: 'Deon');
    await notifyAutoLoginResult(
      status: status,
      lifecycle: AppLifecycleState.paused,
      notificationService: notifications,
    );
    notifications.fail = false;
    await notifyAutoLoginResult(
      status: status,
      lifecycle: AppLifecycleState.paused,
      notificationService: notifications,
    );
    expect(notifications.shown.single.body, 'Signed in as Deon');
  });

  test('notification service is optional', () async {
    await notifyAutoLoginResult(
      status: const AutoLoginStatus(AutoLoginPhase.done),
      lifecycle: AppLifecycleState.paused,
    );
  });
}
