part of 'scheduler_models.dart';

String _actionText(String value, {int max = 120}) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty || normalized.length > max) {
    throw const SchedulerException('invalidAction');
  }
  return normalized;
}

int _positive(int value) {
  if (value <= 0) throw const SchedulerException('invalidAction');
  return value;
}

enum GameItemOperation { use, tune }

GameItemOperation _itemOperation(Map json) {
  if (!json.containsKey('operation')) return GameItemOperation.use;
  return switch (json['operation']) {
    'use' => GameItemOperation.use,
    'tune' => GameItemOperation.tune,
    _ => throw const SchedulerException('invalidAction'),
  };
}

sealed class ScheduledAction {
  String get type;
  Map<String, Object?> toJson();
  static ScheduledAction fromJson(Map<String, dynamic> json) {
    try {
      return switch (json['type']) {
        'localNotification' => LocalNotificationAction.fromJson(json),
        'useItem' => UseItemAction(
          boundUsername: json['boundUsername'] as String,
          character: GameCharacter.fromJson(json['character'] as Map),
          itemName: json['itemName'] as String,
          operation: _itemOperation(json),
        ),
        'payCrew' => PayCrewAction(
          boundUsername: json['boundUsername'] as String,
          character: GameCharacter.fromJson(json['character'] as Map),
          artistId: json['artistId'] as int,
          artistName: json['artistName'] as String,
          bonusLevel: json['bonusLevel'] as int,
          maxCostMinor: json['maxCostMinor'] as int?,
        ),
        _ => throw const SchedulerException('invalidAction'),
      };
    } catch (_) {
      throw const SchedulerException('invalidAction');
    }
  }
}

sealed class GameScheduledAction extends ScheduledAction {
  GameScheduledAction({required String boundUsername, required this.character})
    : boundUsername = _actionText(boundUsername);
  final String boundUsername;
  final GameCharacter character;
  Map<String, Object?> get _target => {
    'type': type,
    'boundUsername': boundUsername,
    'character': character.toJson(),
  };
}

class UseItemAction extends GameScheduledAction {
  UseItemAction({
    required super.boundUsername,
    required super.character,
    required String itemName,
    this.operation = GameItemOperation.use,
  }) : itemName = _actionText(itemName);
  final String itemName;
  final GameItemOperation operation;
  @override
  String get type => 'useItem';
  @override
  Map<String, Object?> toJson() => {
    ..._target,
    'itemName': itemName,
    if (operation != GameItemOperation.use) 'operation': operation.name,
  };
}

class PayCrewAction extends GameScheduledAction {
  PayCrewAction({
    required super.boundUsername,
    required super.character,
    required int artistId,
    required String artistName,
    required this.bonusLevel,
    int? maxCostMinor,
  }) : artistId = _positive(artistId),
       artistName = _actionText(artistName),
       maxCostMinor = maxCostMinor == null ? null : _positive(maxCostMinor) {
    if (bonusLevel < 14 || bonusLevel > 20) {
      throw const SchedulerException('invalidAction');
    }
  }
  final int artistId;
  final String artistName;
  final int bonusLevel;
  final int? maxCostMinor;
  @override
  String get type => 'payCrew';
  @override
  Map<String, Object?> toJson() => {
    ..._target,
    'artistId': artistId,
    'artistName': artistName,
    'bonusLevel': bonusLevel,
    'maxCostMinor': maxCostMinor,
  };
}
