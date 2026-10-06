@Tags(['live'])
library;

import 'dart:io';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

/// Opt-in read-only proof; no capture helper or gameplay executor can run here.
void main() {
  final configured =
      (Platform.environment['POPMUNDO_USERNAME'] ?? '').isNotEmpty &&
      (Platform.environment['POPMUNDO_PASSWORD'] ?? '').isNotEmpty;
  test(
    'independent native login selects owned character without gameplay',
    () async {
      final service = GameActionsService(
        readCredentials: () async => GameCredentials(
          username: Platform.environment['POPMUNDO_USERNAME'] ?? '',
          password: Platform.environment['POPMUNDO_PASSWORD'] ?? '',
        ),
      );
      try {
        final catalog = await service.discoverCharacters();
        final visibleId = int.parse(
          Platform.environment['POPMUNDO_VISIBLE_CHARACTER_ID']!,
        );
        final requestedId = int.tryParse(
          Platform.environment['POPMUNDO_DISCOVERY_CHARACTER_ID'] ?? '',
        );
        final target = catalog.characters.firstWhere(
          (character) => requestedId == null
              ? character.id != visibleId
              : character.id == requestedId,
        );
        expect(target.id, isNot(visibleId));
        final items = await service.discoverItems(
          boundUsername: catalog.username,
          character: target,
        );
        expect(items.every((item) => item.name.isNotEmpty), true);
        print(
          'game-discovery-live visibleId=$visibleId selectedId=${target.id} owned=${catalog.characters.length} itemChoices=${items.length}',
        );
      } on GameActionException catch (error) {
        fail('game-discovery-live failed code=${error.code}');
      } finally {
        await service.dispose();
      }
    },
    skip: !configured
        ? 'Set runtime POPMUNDO_* credentials for this opt-in live proof.'
        : false,
  );
}
