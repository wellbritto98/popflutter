part of 'scheduler_coordinator.dart';

/// Public mutation methods share the coordinator's serialized writer.
extension SchedulerCommands on SchedulerCoordinator {
  Future<SchedulerSnapshot> create(ScheduleDraft draft, {required String id}) =>
      _serialized(() async {
        final snapshot = await _ensureLoaded();
        if (snapshot.rules.any((rule) => rule.id == id)) {
          throw const SchedulerException('duplicateId');
        }
        final now = this.now().toUtc();
        final rule = _arm(
          ScheduledRule(
            id: id,
            revision: 1,
            notificationId: snapshot.nextNotificationId,
            name: draft.name,
            enabled: draft.enabled,
            recurrence: draft.recurrence,
            action: draft.action,
          ),
          now,
          resetAnchor: true,
        );
        if (rule.enabled && rule.lastResult.errorCode == 'zoneUnavailable') {
          throw const SchedulerException('zoneUnavailable');
        }
        return _save(
          SchedulerSnapshot(
            nextSequence: snapshot.nextSequence + 1,
            rules: [...snapshot.rules, rule],
          ),
        );
      });

  Future<SchedulerSnapshot> update(
    String id,
    ScheduleDraft draft, {
    required int expectedRevision,
  }) => _serialized(() async {
    await _ensureLoaded();
    final old = _find(id, expectedRevision: expectedRevision);
    final recurrenceChanged = !_sameCadence(old.recurrence, draft.recurrence);
    final reset = recurrenceChanged || (!old.enabled && draft.enabled);
    var rule = old.copyWith(
      revision: old.revision + 1,
      name: draft.name,
      action: draft.action,
      enabled: draft.enabled,
      recurrence: recurrenceChanged ? draft.recurrence : old.recurrence,
      clearDue: !draft.enabled,
      clearClaim: reset,
      clearAttempt: reset,
    );
    if (reset) rule = _arm(rule, now().toUtc(), resetAnchor: true);
    if (rule.enabled &&
        reset &&
        rule.lastResult.errorCode == 'zoneUnavailable' &&
        rule.nextDueUtc == null) {
      throw const SchedulerException('zoneUnavailable');
    }
    return _replace(rule);
  });

  Future<SchedulerSnapshot> toggle(
    String id, {
    required int expectedRevision,
    required bool enabled,
  }) => _serialized(() async {
    await _ensureLoaded();
    final old = _find(id, expectedRevision: expectedRevision);
    var rule = old.copyWith(
      revision: old.revision + 1,
      enabled: enabled,
      clearDue: !enabled,
      clearClaim: enabled && !old.enabled,
      clearAttempt: enabled && !old.enabled,
    );
    if (enabled && !old.enabled) {
      rule = _arm(rule, now().toUtc(), resetAnchor: true);
      if (rule.nextDueUtc == null) {
        throw const SchedulerException('zoneUnavailable');
      }
    }
    return _replace(rule);
  });

  Future<SchedulerSnapshot> delete(
    String id, {
    required int expectedRevision,
  }) => _serialized(() async {
    await _ensureLoaded();
    _find(id, expectedRevision: expectedRevision);
    return _save(
      SchedulerSnapshot(
        nextSequence: _snapshot!.nextSequence,
        rules: _snapshot!.rules.where((rule) => rule.id != id).toList(),
      ),
    );
  });

  bool _sameCadence(ScheduleRecurrence first, ScheduleRecurrence second) {
    if (first is IntervalRecurrence && second is IntervalRecurrence) {
      return first.quantity == second.quantity && first.unit == second.unit;
    }
    return jsonEncode(first.toJson()) == jsonEncode(second.toJson());
  }
}
