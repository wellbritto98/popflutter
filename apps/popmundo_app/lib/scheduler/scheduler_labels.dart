import 'package:easy_localization/easy_localization.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

String schedulerError(Object error) {
  final code = error is SchedulerException ? error.code : 'runtimeUnavailable';
  final key = switch (code) {
    'permissionDenied' => 'permissionDenied',
    'requestTimeout' => 'uncertain',
    'revisionConflict' => 'conflict',
    'zoneUnavailable' => 'zoneUnavailable',
    'bootConfigurationFailed' => 'bootFailed',
    'unknownSchema' || 'corruptSnapshot' || 'readFailed' => 'unavailable',
    'serviceUnavailable' || 'runtimeUnavailable' => 'serviceUnavailable',
    'ruleNotFound' => 'removed',
    _ => 'saveFailed',
  };
  return ['scheduler', key].join('.').tr();
}

String recurrenceLabel(ScheduleRecurrence recurrence) {
  if (recurrence is IntervalRecurrence) {
    return 'scheduler.every'.tr(
      args: [
        recurrence.quantity.toString(),
        ['scheduler.units', recurrence.unit.name].join('.').tr(),
      ],
    );
  }
  final weekly = recurrence as WeeklyRecurrence;
  final days = weekly.weekdays.toList()..sort();
  return 'scheduler.weeklySummary'.tr(
    args: [
      days
          .map((day) => ['scheduler.days', day.toString()].join('.').tr())
          .join(', '),
      scheduleTime(weekly.hour, weekly.minute),
    ],
  );
}

String scheduleTime(int hour, int minute) => [
  hour.toString().padLeft(2, '0'),
  minute.toString().padLeft(2, '0'),
].join(':');
String _executionError(String? code) => switch (code) {
  'actionTimeout' => 'scheduler.notificationTimeout'.tr(),
  'notificationInitializationFailed' =>
    'scheduler.notificationInitializationFailed'.tr(),
  'permissionDenied' => 'scheduler.notificationDenied'.tr(),
  'zoneUnavailable' => 'scheduler.zoneUnavailable'.tr(),
  _ => 'scheduler.notificationFailed'.tr(),
};
String actionSummary(ScheduledAction action) {
  if (action is UseItemAction) {
    return (action.operation == GameItemOperation.tune
            ? 'scheduler.cardTune'
            : 'scheduler.cardItem')
        .tr(args: [action.character.name, action.itemName]);
  }
  if (action is PayCrewAction) {
    return 'scheduler.cardCrew'.tr(
      args: [
        action.character.name,
        action.artistName,
        action.bonusLevel.toString(),
      ],
    );
  }
  return 'scheduler.localNotification'.tr();
}

String resultLabel(ScheduleResult result) => switch (result.status) {
  ScheduleResultStatus.neverExecuted => 'scheduler.never'.tr(),
  ScheduleResultStatus.submitted => 'scheduler.submitted'.tr(),
  ScheduleResultStatus.confirmed => 'scheduler.gameConfirmed'.tr(),
  ScheduleResultStatus.unavailable => 'scheduler.gameUnavailable'.tr(),
  ScheduleResultStatus.uncertain => 'scheduler.gameUncertain'.tr(),
  ScheduleResultStatus.skippedInterrupted => 'scheduler.interrupted'.tr(),
  ScheduleResultStatus.failed => 'scheduler.failed'.tr(
    args: [_executionError(result.errorCode)],
  ),
};
