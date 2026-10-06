import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameNotificationText {
  const GameNotificationText({required this.title, required this.body});
  final String title, body;
}

/// Asset-only localization usable in a secondary engine without BuildContext.
class GameNotificationMessages {
  GameNotificationMessages(this.strings);
  final Map<String, dynamic> strings;
  static Future<GameNotificationMessages> load(SharedPreferences prefs) async {
    await prefs.reload();
    final saved =
        prefs.getString('locale') ??
        PlatformDispatcher.instance.locale.languageCode;
    final language = saved.split(RegExp('[-_]')).first == 'pt' ? 'pt' : 'en';
    final json = jsonDecode(
      await rootBundle.loadString(
        'assets/translations/$language.json',
        cache: false,
      ),
    ) as Map;
    return GameNotificationMessages(
      Map<String, dynamic>.from(json['scheduler'] as Map),
    );
  }

  String _text(String key, [List<String> args = const []]) {
    var value = strings[key] as String;
    for (final arg in args) {
      value = value.replaceFirst('{}', arg);
    }
    return value;
  }

  String _service(GameScheduledAction action) => _text(action.type);
  GameNotificationText start(GameScheduledAction action) =>
      GameNotificationText(
        title: _text('gameStartTitle', [_service(action)]),
        body: _text('gameCharacterBody', [action.character.name]),
      );
  GameNotificationText result(
    GameScheduledAction action,
    GameActionOutcome outcome,
  ) => GameNotificationText(
    title: _text('gameResultTitle', [
      _service(action),
      _text('gameOutcome_${outcome.status.name}'),
    ]),
    body: _text('gameCharacterBody', [action.character.name]),
  );
}
