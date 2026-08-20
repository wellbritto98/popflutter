// Imported directly (not via the barrel yet) — the barrel export lands in
// task 5, and this file switches to it then, matching the rest of test/.
import 'package:popmundo_utils/src/menu_notifications/menu_notification.dart';
import 'package:test/test.dart';

void main() {
  test('valid JSON map maps every field (MENUNOTIF-05)', () {
    final n = MenuNotification.fromJson({
      'UID': 'abc-123',
      'DateCreated': '2026-08-19',
      'TimeCreated': '10:00',
      'Text': 'You have a new item offer',
      'Url': '/World/Item.aspx?id=1',
      'Repeats': 2,
      'Type': 5,
      'Int1': 42,
    });

    expect(n, isNotNull);
    expect(n!.uid, 'abc-123');
    expect(n.dateCreated, '2026-08-19');
    expect(n.timeCreated, '10:00');
    expect(n.text, 'You have a new item offer');
    expect(n.url, '/World/Item.aspx?id=1');
    expect(n.repeats, 2);
    expect(n.type, 5);
    expect(n.int1, 42);
  });

  test('tolerant coercion: string-encoded ints and missing optional fields', () {
    final n = MenuNotification.fromJson({
      'UID': 'xyz',
      'Repeats': '3',
      'Type': '7',
      'Int1': 'not-a-number',
    });

    expect(n, isNotNull);
    expect(n!.uid, 'xyz');
    expect(n.dateCreated, '');
    expect(n.timeCreated, '');
    expect(n.text, '');
    expect(n.url, '');
    expect(n.repeats, 3);
    expect(n.type, 7);
    expect(n.int1, 0);
  });

  test('malformed entry (not a map) returns null', () {
    expect(MenuNotification.fromJson('not a map'), isNull);
    expect(MenuNotification.fromJson(42), isNull);
    expect(MenuNotification.fromJson(null), isNull);
  });

  test('entry with missing or empty UID returns null', () {
    expect(MenuNotification.fromJson({'Text': 'no uid here'}), isNull);
    expect(MenuNotification.fromJson({'UID': '', 'Text': 'blank uid'}), isNull);
  });
}
