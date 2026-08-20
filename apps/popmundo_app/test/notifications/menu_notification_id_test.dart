import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/notifications/menu_notifications_bridge.dart';

void main() {
  group('menuNotificationIdFor', () {
    test('is deterministic: same uid maps to the same id every time', () {
      const uid = '3f2a9c10-1b2d-4e5f-8a9b-0c1d2e3f4a5b';
      expect(menuNotificationIdFor(uid), menuNotificationIdFor(uid));
    });

    test('is always non-negative (fits Android\'s signed 32-bit id)', () {
      const sampleUids = [
        '3f2a9c10-1b2d-4e5f-8a9b-0c1d2e3f4a5b',
        '00000000-0000-0000-0000-000000000000',
        'ffffffff-ffff-ffff-ffff-ffffffffffff',
        'a',
        '',
        'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
      ];
      for (final uid in sampleUids) {
        expect(menuNotificationIdFor(uid), greaterThanOrEqualTo(0));
      }
    });

    test('distinct uids map to distinct ids (sample set, no collisions)', () {
      final uids = List.generate(50, (i) => 'uid-$i-sample');
      final ids = uids.map(menuNotificationIdFor).toSet();
      expect(ids, hasLength(uids.length));
    });
  });
}
