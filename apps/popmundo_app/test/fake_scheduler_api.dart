import 'dart:async';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:popmundo_app/scheduler/scheduler_client.dart';

import 'scheduler_runtime_test.dart' show Store;

class FakeSchedulerApi implements SchedulerApi {
  final store = Store();
  late final coordinator = SchedulerCoordinator(
    store: store,
    executors: {},
    now: () => DateTime.utc(2026, 10, 4, 12),
    zoneId: () => 'UTC',
  );
  Completer<void>? listBlock;
  int creates = 0, updates = 0, lists = 0;
  SchedulerSnapshot? refreshedSnapshot;
  bool loseCreateReply = false, failList = false;
  String? failure;
  Completer<void>? saveBlock;
  String? createdId;
  ScheduleDraft? savedDraft;
  @override
  Future<SchedulerSnapshot> list() async {
    lists++;
    await listBlock?.future;
    if (failList) throw const SchedulerException('readFailed');
    return refreshedSnapshot ?? await coordinator.list();
  }

  @override
  Future<SchedulerSnapshot> create(
    ScheduleDraft draft, {
    required String id,
  }) async {
    creates++;
    createdId = id;
    savedDraft = draft;
    await saveBlock?.future;
    if (failure != null) throw SchedulerException(failure!);
    final snapshot = await coordinator.create(draft, id: id);
    if (loseCreateReply) {
      loseCreateReply = false;
      throw const SchedulerException('requestTimeout');
    }
    return snapshot;
  }

  @override
  Future<SchedulerSnapshot> update(
    ScheduledRule rule,
    ScheduleDraft draft,
  ) async {
    updates++;
    savedDraft = draft;
    if (failure != null) throw SchedulerException(failure!);
    return coordinator.update(rule.id, draft, expectedRevision: rule.revision);
  }

  @override
  Future<SchedulerSnapshot> toggle(ScheduledRule rule, bool enabled) =>
      coordinator.toggle(
        rule.id,
        expectedRevision: rule.revision,
        enabled: enabled,
      );
  @override
  Future<SchedulerSnapshot> delete(ScheduledRule rule) =>
      coordinator.delete(rule.id, expectedRevision: rule.revision);
}
