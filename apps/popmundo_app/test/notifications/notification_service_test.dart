import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/notifications/fake_notification_service.dart';
import 'package:popmundo_app/notifications/local_notifications_service.dart';

void main() {
  group('FakeNotificationService.showNotification', () {
    test('records id/title/body/payload (MENUNOTIF-06)', () async {
      final service = FakeNotificationService();

      await service.showNotification(
        id: 42,
        title: 'Item offer',
        body: '2026-08-19 10:00 - Ada',
        payload: '/World/Popmundo.aspx/Item/1',
      );

      expect(service.shownNotifications, hasLength(1));
      final shown = service.shownNotifications.single;
      expect(shown.id, 42);
      expect(shown.title, 'Item offer');
      expect(shown.body, '2026-08-19 10:00 - Ada');
      expect(shown.payload, '/World/Popmundo.aspx/Item/1');
    });

    test('records one call per invocation, in order', () async {
      final service = FakeNotificationService();

      await service.showNotification(id: 1, title: 'A', body: 'a');
      await service.showNotification(id: 2, title: 'B', body: 'b');

      expect(service.shownNotifications, hasLength(2));
      expect(service.shownNotifications[0].id, 1);
      expect(service.shownNotifications[1].id, 2);
    });

    test('payload is optional and defaults to null', () async {
      final service = FakeNotificationService();

      await service.showNotification(id: 1, title: 'A', body: 'a');

      expect(service.shownNotifications.single.payload, isNull);
    });
  });

  group('LocalNotificationsService.showNotification', () {
    test('no-ops without throwing when the plugin was never initialized',
        () async {
      // Mirrors showTestNotification()'s existing not-initialized guard —
      // this keeps the call safe even if init failed at startup.
      final service = LocalNotificationsService();

      await expectLater(
        service.showNotification(id: 1, title: 'A', body: 'a'),
        completes,
      );
    });
  });
}
