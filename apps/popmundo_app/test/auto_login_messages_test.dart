import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/autologin/auto_login_messages.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'localization_helpers.dart';

/// Renders whatever [autoLoginStatusMessage] returns for [status], so the real
/// catalogs are exercised instead of the key strings.
class _MessageProbe extends StatelessWidget {
  const _MessageProbe(this.status);

  final AutoLoginStatus status;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Text(autoLoginStatusMessage(status) ?? '<null>'),
      );
}

void main() {
  Future<String> messageFor(
    WidgetTester tester,
    AutoLoginStatus status, {
    Locale locale = const Locale('en'),
  }) async {
    await pumpLocalized(tester, _MessageProbe(status), startLocale: locale);
    return tester.widget<Text>(find.byType(Text)).data!;
  }

  testWidgets('progress phases resolve to localized text', (tester) async {
    expect(
      await messageFor(tester, const AutoLoginStatus(AutoLoginPhase.detected)),
      'Session expired — signing in…',
    );
    expect(
      await messageFor(
          tester, const AutoLoginStatus(AutoLoginPhase.authenticating)),
      'Authenticating…',
    );
  });

  testWidgets('character name is interpolated into progress text',
      (tester) async {
    expect(
      await messageFor(
        tester,
        const AutoLoginStatus(AutoLoginPhase.choosingCharacter,
            characterName: 'Deon Drinkwater'),
      ),
      'Selecting Deon Drinkwater…',
    );
    expect(
      await messageFor(
        tester,
        const AutoLoginStatus(AutoLoginPhase.done,
            characterName: 'Deon Drinkwater'),
      ),
      'Signed in as Deon Drinkwater',
    );
  });

  testWidgets('the not-found message points at the full name', (tester) async {
    final message = await messageFor(
      tester,
      const AutoLoginStatus.failed(AutoLoginFailure.characterNotFound,
          characterName: 'Deon'),
    );
    expect(message, contains('Deon'));
    expect(message, contains('full name'));
  });

  testWidgets('the ambiguous message names the duplicate', (tester) async {
    expect(
      await messageFor(
        tester,
        const AutoLoginStatus.failed(AutoLoginFailure.characterAmbiguous,
            characterName: 'Deon Drinkwater'),
      ),
      contains('more than one character'),
    );
  });

  testWidgets('the server message is surfaced verbatim', (tester) async {
    expect(
      await messageFor(
        tester,
        const AutoLoginStatus.failed(AutoLoginFailure.serverRejected,
            serverMessage: 'Character unavailable'),
      ),
      'Auto Login failed: Character unavailable',
    );
  });

  testWidgets('every failure resolves in both catalogs (no raw keys)',
      (tester) async {
    for (final locale in const [Locale('en'), Locale('pt')]) {
      for (final failure in AutoLoginFailure.values) {
        final message = await messageFor(
          tester,
          AutoLoginStatus.failed(failure, characterName: 'X', serverMessage: 'Y'),
          locale: locale,
        );
        expect(message, isNot(startsWith('autologin.')),
            reason: 'missing ${locale.languageCode} key for $failure');
        expect(message, isNot(contains('{}')),
            reason: 'unfilled placeholder for $failure');
      }
    }
  });

  testWidgets('portuguese catalog is used when the locale is pt',
      (tester) async {
    expect(
      await messageFor(
        tester,
        const AutoLoginStatus(AutoLoginPhase.done, characterName: 'Deon'),
        locale: const Locale('pt'),
      ),
      'Conectado como Deon',
    );
  });
}
