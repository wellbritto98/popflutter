enum AutoLoginPhase { detected, authenticating, choosingCharacter, done, failed }

enum AutoLoginFailure {
  /// The page carried no `#aspnetForm` to serialize.
  missingForm,

  /// The login POST landed back on the login page.
  invalidCredentials,

  /// ChooseCharacter rendered zero character boxes.
  noCharacters,

  /// No `div.box` heading matched the configured full name.
  characterNotFound,

  /// More than one box carries the configured full name.
  characterAmbiguous,

  /// The game's notification service reported an error for the last POST.
  serverRejected,

  /// The native HTTP handshake could not reach the game.
  networkError,
}

/// One step of an auto-login cycle, surfaced to the shell for snackbars.
class AutoLoginStatus {
  const AutoLoginStatus(
    this.phase, {
    this.failure,
    this.characterName,
    this.serverMessage,
  });

  const AutoLoginStatus.failed(
    AutoLoginFailure failure, {
    String? characterName,
    String? serverMessage,
  }) : this(
          AutoLoginPhase.failed,
          failure: failure,
          characterName: characterName,
          serverMessage: serverMessage,
        );

  final AutoLoginPhase phase;
  final AutoLoginFailure? failure;
  final String? characterName;

  /// Text from `GetPageNotifications` when [failure] is
  /// [AutoLoginFailure.serverRejected].
  final String? serverMessage;

  @override
  String toString() =>
      'AutoLoginStatus($phase, failure: $failure, character: $characterName)';
}
