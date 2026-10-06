import 'package:popmundo_utils/popmundo_utils.dart';

/// Read-only discovery port, separate from the durable scheduler CRUD API.
abstract interface class GameActionsApi {
  Future<GameCharacterCatalog> discoverCharacters();
  Future<List<GameItemChoice>> discoverItems({
    required String boundUsername,
    required GameCharacter character,
  });
  Future<GameCrewOptions> discoverCrew({
    required String boundUsername,
    required GameCharacter character,
  });
}

const boundedGameRpcCodes = {
  'accountChanged',
  'artistMismatch',
  'artistUnavailable',
  'bonusUnavailable',
  'characterAmbiguous',
  'characterMismatch',
  'characterUnavailable',
  'charactersUnavailable',
  'credentialsMissing',
  'credentialsUnavailable',
  'duplicateAction',
  'formUnavailable',
  'invalidCredentials',
  'itemUnavailable',
  'networkError',
  'notificationFailed',
  'notificationInitializationFailed',
  'occurrenceExpired',
  'permissionDenied',
  'preflightUnavailable',
  'responseTooLarge',
  'routeMismatch',
  'serviceUnavailable',
  'unsafeTarget',
};

/// Known scheduler failures stay intact. Game codes leave the engine only
/// when they are on the bounded list; anything else becomes a safe code.
String boundedSchedulerCode(Object error) {
  if (error is SchedulerException) return error.code;
  if (error is GameActionException &&
      boundedGameRpcCodes.contains(error.code)) {
    return error.code;
  }
  return 'runtimeUnavailable';
}

class NativeGameActionsApi implements GameActionsApi {
  NativeGameActionsApi(this.service);
  final GameActionsService service;
  @override
  Future<GameCharacterCatalog> discoverCharacters() =>
      service.discoverCharacters();
  @override
  Future<List<GameItemChoice>> discoverItems({
    required String boundUsername,
    required GameCharacter character,
  }) =>
      service.discoverItems(boundUsername: boundUsername, character: character);
  @override
  Future<GameCrewOptions> discoverCrew({
    required String boundUsername,
    required GameCharacter character,
  }) =>
      service.discoverCrew(boundUsername: boundUsername, character: character);
}
