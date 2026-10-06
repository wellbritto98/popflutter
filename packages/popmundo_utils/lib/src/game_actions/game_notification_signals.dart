import 'dart:convert';

import 'game_action_contracts.dart';

/// Strictly reads every signal, rather than trusting the last notification.
class GameNotificationSignals {
  GameNotificationSignals._(this.statuses, this.valid);
  final List<int> statuses;
  final bool valid;
  factory GameNotificationSignals.parse(String text) {
    try {
      final envelope = jsonDecode(text);
      if (envelope is! Map || !envelope.containsKey('d')) {
        return GameNotificationSignals._([], false);
      }
      dynamic payload = envelope['d'];
      if (payload is String) payload = jsonDecode(payload);
      final values = payload is List ? payload : [payload];
      final statuses = <int>[];
      for (final value in values) {
        if (value is! Map ||
            value['Text'] is! String ||
            value['Status'] is! int ||
            ![0, 1, 2].contains(value['Status'])) {
          return GameNotificationSignals._([], false);
        }
        statuses.add(value['Status'] as int);
      }
      return GameNotificationSignals._(statuses, true);
    } catch (_) {
      return GameNotificationSignals._([], false);
    }
  }
  bool get isNeutral => valid && statuses.every((status) => status == 0);
  GameActionOutcome get outcome {
    if (valid && statuses.isNotEmpty && statuses.every((s) => s == 1)) {
      return const GameActionOutcome(status: GameActionStatus.confirmed);
    }
    if (valid && statuses.isNotEmpty && statuses.every((s) => s == 2)) {
      return const GameActionOutcome(
        status: GameActionStatus.failed,
        errorCode: 'serverRejected',
      );
    }
    return const GameActionOutcome(
      status: GameActionStatus.uncertain,
      errorCode: 'outcomeUncertain',
    );
  }
}
