part of 'scheduler_models.dart';

class GameCharacter {
  GameCharacter({required int id, required String name})
    : id = _positive(id),
      name = _actionText(name);
  final int id;
  final String name;
  factory GameCharacter.fromJson(Map json) {
    try {
      return GameCharacter(id: json['id'] as int, name: json['name'] as String);
    } catch (_) {
      throw const SchedulerException('invalidAction');
    }
  }
  Map<String, Object?> toJson() => {'id': id, 'name': name};
}

class GameCharacterCatalog {
  GameCharacterCatalog({
    required String username,
    required List<GameCharacter> characters,
  }) : username = _actionText(username),
       characters = List.unmodifiable(characters);
  final String username;
  final List<GameCharacter> characters;
  factory GameCharacterCatalog.fromJson(Map json) {
    try {
      return GameCharacterCatalog(
        username: json['username'] as String,
        characters: (json['characters'] as List)
            .map((v) => GameCharacter.fromJson(v as Map))
            .toList(),
      );
    } catch (_) {
      throw const SchedulerException('invalidAction');
    }
  }
  Map<String, Object?> toJson() => {
    'username': username,
    'characters': characters.map((c) => c.toJson()).toList(),
  };
}

class GameItemChoice {
  GameItemChoice({required String name, this.operation = GameItemOperation.use})
    : name = _actionText(name);
  final String name;
  final GameItemOperation operation;
  factory GameItemChoice.fromJson(Map json) {
    try {
      return GameItemChoice(
        name: json['name'] as String,
        operation: _itemOperation(json),
      );
    } catch (_) {
      throw const SchedulerException('invalidAction');
    }
  }
  Map<String, Object?> toJson() => {
    'name': name,
    if (operation != GameItemOperation.use) 'operation': operation.name,
  };
}

class GameBonusChoice {
  GameBonusChoice({
    required this.level,
    required String label,
    required int costMinor,
  }) : label = _actionText(label),
       costMinor = _positive(costMinor) {
    if (level < 14 || level > 20) {
      throw const SchedulerException('invalidAction');
    }
  }
  final int level;
  final String label;
  final int costMinor;
  factory GameBonusChoice.fromJson(Map json) {
    try {
      return GameBonusChoice(
        level: json['level'] as int,
        label: json['label'] as String,
        costMinor: json['costMinor'] as int,
      );
    } catch (_) {
      throw const SchedulerException('invalidAction');
    }
  }
  Map<String, Object?> toJson() => {
    'level': level,
    'label': label,
    'costMinor': costMinor,
  };
}

class GameCrewOptions {
  GameCrewOptions({
    required int artistId,
    required String artistName,
    required List<GameBonusChoice> bonuses,
  }) : artistId = _positive(artistId),
       artistName = _actionText(artistName),
       bonuses = List.unmodifiable(bonuses);
  final int artistId;
  final String artistName;
  final List<GameBonusChoice> bonuses;
  factory GameCrewOptions.fromJson(Map json) {
    try {
      return GameCrewOptions(
        artistId: json['artistId'] as int,
        artistName: json['artistName'] as String,
        bonuses: (json['bonuses'] as List)
            .map((v) => GameBonusChoice.fromJson(v as Map))
            .toList(),
      );
    } catch (_) {
      throw const SchedulerException('invalidAction');
    }
  }
  Map<String, Object?> toJson() => {
    'artistId': artistId,
    'artistName': artistName,
    'bonuses': bonuses.map((c) => c.toJson()).toList(),
  };
}
