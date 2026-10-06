import 'dart:convert';
part 'scheduler_actions.dart';
part 'game_action_choices.dart';

class SchedulerException implements Exception {
  const SchedulerException(this.code);
  final String code;
  @override
  String toString() => code;
}

String _text(String value, int max) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.length > max) {
    throw const SchedulerException('invalidText');
  }
  return trimmed;
}

DateTime _utc(Object? value) {
  if (value is! String || !value.endsWith('Z')) {
    throw const SchedulerException('invalidTimestamp');
  }
  return DateTime.parse(value).toUtc();
}

enum IntervalUnit { seconds, minutes, hours, days }

sealed class ScheduleRecurrence {
  Map<String, Object?> toJson();
  static ScheduleRecurrence fromJson(Map<String, dynamic> json) =>
      switch (json['type']) {
        'interval' => IntervalRecurrence.fromJson(json),
        'weekly' => WeeklyRecurrence.fromJson(json),
        _ => throw const SchedulerException('invalidRecurrence'),
      };
}

class IntervalRecurrence extends ScheduleRecurrence {
  IntervalRecurrence({
    this.quantity = 1,
    this.unit = IntervalUnit.minutes,
    required DateTime anchorUtc,
  }) : anchorUtc = anchorUtc.toUtc() {
    if (quantity < 1 || quantity > 9999) {
      throw const SchedulerException('invalidQuantity');
    }
  }
  final int quantity;
  final IntervalUnit unit;
  final DateTime anchorUtc;
  Duration get duration => Duration(
    seconds:
        quantity *
        switch (unit) {
          IntervalUnit.seconds => 1,
          IntervalUnit.minutes => 60,
          IntervalUnit.hours => 3600,
          IntervalUnit.days => 86400,
        },
  );
  factory IntervalRecurrence.fromJson(Map<String, dynamic> json) =>
      IntervalRecurrence(
        quantity: json['quantity'] as int,
        unit: IntervalUnit.values.byName(json['unit'] as String),
        anchorUtc: _utc(json['anchorUtc']),
      );
  @override
  Map<String, Object?> toJson() => {
    'type': 'interval',
    'quantity': quantity,
    'unit': unit.name,
    'anchorUtc': anchorUtc.toIso8601String(),
  };
}

class WeeklyRecurrence extends ScheduleRecurrence {
  WeeklyRecurrence({
    required Set<int> weekdays,
    required this.hour,
    required this.minute,
  }) : weekdays = Set.unmodifiable(weekdays) {
    if (weekdays.isEmpty ||
        weekdays.any((day) => day < 1 || day > 7) ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw const SchedulerException('invalidWeekly');
    }
  }
  final Set<int> weekdays;
  final int hour;
  final int minute;
  factory WeeklyRecurrence.fromJson(Map<String, dynamic> json) =>
      WeeklyRecurrence(
        weekdays: (json['weekdays'] as List).cast<int>().toSet(),
        hour: json['hour'] as int,
        minute: json['minute'] as int,
      );
  @override
  Map<String, Object?> toJson() => {
    'type': 'weekly',
    'weekdays': weekdays.toList()..sort(),
    'hour': hour,
    'minute': minute,
  };
}

class LocalNotificationAction extends ScheduledAction {
  LocalNotificationAction({required String title, required String body})
    : title = _text(title, 120),
      body = _text(body, 1000);
  @override
  String get type => 'localNotification';
  final String title;
  final String body;
  factory LocalNotificationAction.fromJson(Map<String, dynamic> json) {
    if (json['type'] != 'localNotification') {
      throw const SchedulerException('invalidAction');
    }
    return LocalNotificationAction(
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }
  @override
  Map<String, Object?> toJson() => {
    'type': 'localNotification',
    'title': title,
    'body': body,
  };
}

class ScheduleDraft {
  ScheduleDraft({
    required String name,
    required this.recurrence,
    required this.action,
    this.enabled = true,
  }) : name = _text(name, 80);
  final String name;
  final bool enabled;
  final ScheduleRecurrence recurrence;
  final ScheduledAction action;
}

class ScheduleClaim {
  ScheduleClaim({
    required this.revision,
    required DateTime plannedUtc,
    this.localSlot,
  }) : plannedUtc = plannedUtc.toUtc() {
    if (revision < 1) throw const SchedulerException('invalidRevision');
  }
  final int revision;
  final DateTime plannedUtc;
  final String? localSlot;
  factory ScheduleClaim.fromJson(Map<String, dynamic> json) => ScheduleClaim(
    revision: json['revision'] as int,
    plannedUtc: _utc(json['plannedUtc']),
    localSlot: json['localSlot'] as String?,
  );
  Map<String, Object?> toJson() => {
    'revision': revision,
    'plannedUtc': plannedUtc.toIso8601String(),
    'localSlot': localSlot,
  };
}

enum ScheduleResultStatus {
  neverExecuted,
  submitted,
  confirmed,
  unavailable,
  uncertain,
  failed,
  skippedInterrupted,
}

class ScheduleResult {
  ScheduleResult({required this.status, DateTime? atUtc, this.errorCode})
    : atUtc = atUtc?.toUtc();
  final ScheduleResultStatus status;
  final DateTime? atUtc;
  final String? errorCode;
  factory ScheduleResult.fromJson(Map<String, dynamic> json) => ScheduleResult(
    status: ScheduleResultStatus.values.byName(json['status'] as String),
    atUtc: json['atUtc'] == null ? null : _utc(json['atUtc']),
    errorCode: json['errorCode'] as String?,
  );
  Map<String, Object?> toJson() => {
    'status': status.name,
    'atUtc': atUtc?.toIso8601String(),
    'errorCode': errorCode,
  };
}

class ScheduledRule {
  ScheduledRule({
    required this.id,
    required this.revision,
    required this.notificationId,
    required String name,
    required this.enabled,
    required this.recurrence,
    required this.action,
    DateTime? nextDueUtc,
    DateTime? lastAttemptUtc,
    this.zoneId,
    this.lastClaim,
    ScheduleResult? lastResult,
  }) : name = _text(name, 80),
       nextDueUtc = nextDueUtc?.toUtc(),
       lastAttemptUtc = lastAttemptUtc?.toUtc(),
       lastResult =
           lastResult ??
           ScheduleResult(status: ScheduleResultStatus.neverExecuted) {
    if (id.isEmpty ||
        revision < 1 ||
        notificationId >= 0 ||
        notificationId < -2147483648 ||
        (!enabled && nextDueUtc != null)) {
      throw const SchedulerException('invalidRule');
    }
  }
  final String id;
  final int revision;
  final int notificationId;
  final String name;
  final bool enabled;
  final ScheduleRecurrence recurrence;
  final ScheduledAction action;
  final DateTime? nextDueUtc;
  final DateTime? lastAttemptUtc;
  final String? zoneId;
  final ScheduleClaim? lastClaim;
  final ScheduleResult lastResult;

  ScheduledRule copyWith({
    int? revision,
    String? name,
    bool? enabled,
    ScheduleRecurrence? recurrence,
    ScheduledAction? action,
    DateTime? nextDueUtc,
    DateTime? lastAttemptUtc,
    bool clearDue = false,
    bool clearAttempt = false,
    String? zoneId,
    ScheduleClaim? lastClaim,
    bool clearClaim = false,
    ScheduleResult? lastResult,
  }) => ScheduledRule(
    id: id,
    revision: revision ?? this.revision,
    notificationId: notificationId,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    recurrence: recurrence ?? this.recurrence,
    action: action ?? this.action,
    nextDueUtc: clearDue ? null : nextDueUtc ?? this.nextDueUtc,
    lastAttemptUtc: clearAttempt ? null : lastAttemptUtc ?? this.lastAttemptUtc,
    zoneId: zoneId ?? this.zoneId,
    lastClaim: clearClaim ? null : lastClaim ?? this.lastClaim,
    lastResult: lastResult ?? this.lastResult,
  );

  factory ScheduledRule.fromJson(Map<String, dynamic> json) => ScheduledRule(
    id: json['id'] as String,
    revision: json['revision'] as int,
    notificationId: json['notificationId'] as int,
    name: json['name'] as String,
    enabled: json['enabled'] as bool,
    recurrence: ScheduleRecurrence.fromJson(
      Map<String, dynamic>.from(json['recurrence'] as Map),
    ),
    action: ScheduledAction.fromJson(
      Map<String, dynamic>.from(json['action'] as Map),
    ),
    nextDueUtc: json['nextDueUtc'] == null ? null : _utc(json['nextDueUtc']),
    lastAttemptUtc: json['lastAttemptUtc'] == null
        ? null
        : _utc(json['lastAttemptUtc']),
    zoneId: json['zoneId'] as String?,
    lastClaim: json['lastClaim'] == null
        ? null
        : ScheduleClaim.fromJson(
            Map<String, dynamic>.from(json['lastClaim'] as Map),
          ),
    lastResult: ScheduleResult.fromJson(
      Map<String, dynamic>.from(json['lastResult'] as Map),
    ),
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'revision': revision,
    'notificationId': notificationId,
    'name': name,
    'enabled': enabled,
    'recurrence': recurrence.toJson(),
    'action': action.toJson(),
    'nextDueUtc': nextDueUtc?.toIso8601String(),
    if (lastAttemptUtc != null)
      'lastAttemptUtc': lastAttemptUtc!.toIso8601String(),
    'zoneId': zoneId,
    'lastClaim': lastClaim?.toJson(),
    'lastResult': lastResult.toJson(),
  };
}

class SchedulerSnapshot {
  SchedulerSnapshot({
    this.nextSequence = 1,
    List<ScheduledRule> rules = const [],
  }) : rules = List.unmodifiable(rules) {
    if (nextSequence < 1 ||
        nextSequence > 2147483649 ||
        rules.map((r) => r.id).toSet().length != rules.length ||
        rules.map((r) => r.notificationId).toSet().length != rules.length ||
        rules.any((r) => -r.notificationId >= nextSequence)) {
      throw const SchedulerException('invalidSnapshot');
    }
  }
  static const storageKey = 'service_scheduler.v1';
  final int nextSequence;
  final List<ScheduledRule> rules;
  int get nextNotificationId {
    if (nextSequence > 2147483648) {
      throw const SchedulerException('idExhausted');
    }
    return -nextSequence;
  }

  factory SchedulerSnapshot.decode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['schemaVersion'] != 1) {
        throw const SchedulerException('unknownSchema');
      }
      return SchedulerSnapshot(
        nextSequence: json['nextSequence'] as int,
        rules: (json['rules'] as List)
            .map(
              (value) => ScheduledRule.fromJson(
                Map<String, dynamic>.from(value as Map),
              ),
            )
            .toList(),
      );
    } on SchedulerException {
      rethrow;
    } catch (_) {
      throw const SchedulerException('corruptSnapshot');
    }
  }
  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'nextSequence': nextSequence,
    'rules': rules.map((r) => r.toJson()).toList(),
  };
  String encode() => jsonEncode(toJson());
}
