import 'package:flutter/foundation.dart';

/// One dynamic entry registered via `GM.registerMenuCommand`.
@immutable
class GmMenuCommand {
  const GmMenuCommand({
    required this.scriptId,
    required this.commandId,
    required this.caption,
  });

  final String scriptId;
  final String commandId;
  final String caption;
}

/// Accumulates GM menu commands until cleared on navigation.
class GmMenuRegistry extends ChangeNotifier {
  final _commands = <GmMenuCommand>[];

  List<GmMenuCommand> get commands => List.unmodifiable(_commands);

  void register(GmMenuCommand command) {
    _commands.removeWhere(
      (c) => c.scriptId == command.scriptId && c.commandId == command.commandId,
    );
    _commands.add(command);
    notifyListeners();
  }

  void clear() {
    if (_commands.isEmpty) return;
    _commands.clear();
    notifyListeners();
  }
}

/// State for an in-app GM notification banner.
@immutable
class GmNotificationState {
  const GmNotificationState({
    required this.callId,
    required this.title,
    required this.text,
  });

  final String callId;
  final String title;
  final String text;
}

/// Holds the currently visible GM notification, if any.
class GmNotificationController extends ChangeNotifier {
  GmNotificationState? _current;

  GmNotificationState? get current => _current;

  void show(GmNotificationState state) {
    _current = state;
    notifyListeners();
  }

  void dismiss() {
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }
}
