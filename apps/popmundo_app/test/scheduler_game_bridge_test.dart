import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/scheduler_editor.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'fake_scheduler_api.dart';
import 'localization_helpers.dart';

void main() {
  testWidgets('offline text edit preserves saved game character and effect', (
    tester,
  ) async {
    final api = FakeSchedulerApi();
    final action = UseItemAction(
      boundUsername: 'saved-account',
      character: GameCharacter(id: 42, name: 'Saved Character'),
      itemName: 'Exact Item',
    );
    final original = (await api.create(
      ScheduleDraft(
        name: 'Original',
        recurrence: IntervalRecurrence(
          quantity: 3,
          unit: IntervalUnit.hours,
          anchorUtc: DateTime.utc(2026, 10, 4, 12),
        ),
        action: action,
      ),
      id: 'saved-game',
    )).rules.single;
    await pumpLocalized(
      tester,
      SchedulerEditor(
        api: api,
        rule: original,
        ensurePermission: () async => true,
      ),
    );
    expect(find.text('Saved Character'), findsOneWidget);
    expect(find.byKey(const Key('schedule-title')), findsNothing);
    expect(find.byKey(const Key('schedule-body')), findsNothing);
    await tester.enterText(find.byKey(const Key('schedule-name')), 'Edited');
    await tester.tap(find.byKey(const Key('schedule-save')));
    await tester.pumpAndSettle();
    final saved = SchedulerSnapshot.decode(api.store.raw!).rules.single;
    expect(saved.action.toJson(), action.toJson());
    expect(saved.name, 'Edited');
    expect(saved.id, original.id);
    expect(saved.notificationId, original.notificationId);
    expect(saved.recurrence.toJson(), original.recurrence.toJson());
    expect(saved.nextDueUtc, original.nextDueUtc);
    expect(api.lists, 0);
    expect(api.updates, 1);
  });
}
