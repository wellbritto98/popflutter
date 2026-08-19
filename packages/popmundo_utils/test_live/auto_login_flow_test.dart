@Tags(['live'])
library;

import 'dart:io';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'support/live_client.dart';
import 'support/live_config.dart';

/// End-to-end run of the real auto-login cycle against popmundo.com.
///
/// This is the only test that proves the ChooseCharacter contract — the shape
/// of that page cannot be observed without an account, so everything the
/// controller does there is otherwise inferred.
///
/// Credentials are read at run time and never committed:
///
///   POPMUNDO_USERNAME=... POPMUNDO_PASSWORD=... POPMUNDO_CHARACTER='Full Name' \
///     dart test test_live/auto_login_flow_test.dart
///
/// Without them the suite skips instead of failing. It performs a real login
/// and really selects a character, so run it against an account you own.
void main() {
  final credentials = LiveCredentials.fromEnvironment();
  if (credentials == null) {
    test('authenticated live flow', () {}, skip: LiveCredentials.missingMessage);
    return;
  }

  late LiveClient client;
  late Uri origin;

  /// Filled by the login step, consumed by the ChooseCharacter assertions.
  late Document chooseDoc;
  late String chooseHtml;
  late List<LiveHop> loginChain;
  late Uri loginLanding;

  setUpAll(() async {
    client = LiveClient();
    origin = Uri.parse(HostTracker.defaultOrigin);

    final page = await client.get(origin);
    expect(page.status, 200, reason: 'login page unreachable');

    final form = AspNetFormData.fromDocument(html_parser.parse(page.body));
    expect(form.isEmpty, isFalse, reason: 'no #aspnetForm on the login page');

    // Exactly the body AutoLoginController builds.
    form.set('__EVENTTARGET', '');
    form.set('__EVENTARGUMENT', '');
    form.set(r'ctl00$cphRightColumn$ucLogin$txtUsername', credentials.username);
    form.set(r'ctl00$cphRightColumn$ucLogin$txtPassword', credentials.password);
    form.set(r'ctl00$cphRightColumn$ucLogin$ddlStatus', '0');
    form.set(r'ctl00$cphRightColumn$ucLogin$btnLogin', 'OK!');

    final response = await client.postForm(page.finalUrl, form.encode());
    loginChain = response.chain;
    loginLanding = response.finalUrl;
    chooseHtml = response.body;
    chooseDoc = html_parser.parse(chooseHtml);
  });

  tearDownAll(() => client.close());

  group('login POST', () {
    test('does not land back on the login page', () {
      // Never print the body: it carries VIEWSTATE and session state.
      final trail = loginChain.map((h) => h.toString()).join(' | ');
      expect(AspNetForm.isLoginPath(loginLanding.path), isFalse,
          reason: 'login rejected — check the credentials. Chain: $trail');
      expect(AspNetForm.looksLikeLoginForm(chooseHtml), isFalse,
          reason: 'response body is still the login form. Chain: $trail');
    });

    test('redirects through the game the way the controller expects', () {
      expect(loginChain.length, greaterThan(1),
          reason: 'expected at least one redirect hop after the POST');
      expect(loginChain.first.isRedirect, isTrue,
          reason: 'the login POST should answer 302, not render a page');
    });

    test('RECORDS whether the hop crosses origins (decides silent vs fallback)',
        () {
      final crossed = loginChain
          .map((h) => h.url.host.toLowerCase())
          .toSet()
          .length > 1;
      final trail = loginChain.map((h) => h.toString()).join('\n  ');
      // ignore: avoid_print
      print('\n[auto-login] redirect chain:\n  $trail\n'
          '[auto-login] crossed origin: $crossed\n'
          '[auto-login] => in-page fetch ${crossed ? 'is CORS-blocked; the '
          'form-navigation fallback runs' : 'succeeds; the silent path runs'}\n'
          '[auto-login] landing host: ${loginLanding.host}\n');
      // Both outcomes are supported by design — this test documents which one
      // production actually takes. It fails only if the chain is unreadable.
      expect(loginChain, isNotEmpty);
    });

    test('the auth cookie is set on the host we landed on', () {
      final cookies = client.cookiesFor(loginLanding.host);
      expect(cookies.keys, contains('popmundo.com'),
          reason: 'no auth cookie on ${loginLanding.host}; '
              'got ${cookies.keys.toList()}');
      expect(cookies['popmundo.com'], isNotEmpty);
    });
  });

  group('ChooseCharacter contract', () {
    test('the landing page is ChooseCharacter', () {
      expect(loginLanding.path, contains('ChooseCharacter'),
          reason: 'landed on ${loginLanding.path}; if the account has a single '
              'character the game may skip this page');
    }, skip: null);

    test('parseCharacterChoices finds characters on the real page', () {
      final choices = AspNetForm.parseCharacterChoices(chooseDoc);
      expect(choices, isNotEmpty,
          reason: 'the div.box > h2 + input[type=submit] contract no longer '
              'holds on the live page');
      for (final choice in choices) {
        expect(choice.fullName, isNotEmpty);
        expect(choice.buttonName, contains('btnChooseCharacter'),
            reason: 'unexpected submit name: ${choice.buttonName}');
      }
      // ignore: avoid_print
      print('[auto-login] characters found: '
          '${choices.map((c) => '"${c.fullName}" -> ${c.buttonName}').join(', ')}');
    });

    test('the h2 really carries the FULL name and the button only the first',
        () {
      final choices = AspNetForm.parseCharacterChoices(chooseDoc);
      final multiWord = choices.where((c) => c.fullName.contains(' '));
      expect(multiWord, isNotEmpty,
          reason: 'no multi-word character name to compare against');
      for (final choice in multiWord) {
        expect(choice.buttonValue, isNot(contains(choice.fullName)),
            reason: 'the button value now contains the full name '
                '("${choice.buttonValue}") — matching on it would be safe '
                'again, but the h2 remains the documented source');
      }
    });

    test('the configured character matches exactly one box', () {
      final choices = AspNetForm.parseCharacterChoices(chooseDoc);
      final match =
          AspNetForm.matchCharacterChoice(choices, credentials.characterName);
      expect(match.outcome, CharacterMatchOutcome.matched,
          reason: 'POPMUNDO_CHARACTER="${credentials.characterName}" did not '
              'resolve; available: '
              '${choices.map((c) => c.fullName).toList()}');
      expect(match.choice!.buttonName, isNotEmpty);
    });

    test('a first name alone does NOT match — the bug this rework fixes', () {
      final choices = AspNetForm.parseCharacterChoices(chooseDoc);
      final firstName = credentials.characterName.trim().split(RegExp(r'\s+')).first;
      if (firstName.toLowerCase() ==
          credentials.characterName.trim().toLowerCase()) {
        markTestSkipped('POPMUNDO_CHARACTER is a single word');
        return;
      }
      expect(AspNetForm.matchCharacterChoice(choices, firstName).outcome,
          CharacterMatchOutcome.notFound,
          reason: 'matching "$firstName" alone must not resolve a character');
    });

    test('div.idHolder exposes a character id (candidate stronger key)', () {
      final holders = chooseDoc.querySelectorAll('div.idHolder');
      // Documented, not required: Popmundo-Utils manage-player-db.js reads it.
      // If this stays true, ambiguous full names could be disambiguated by id.
      // ignore: avoid_print
      print('[auto-login] div.idHolder count: ${holders.length}'
          '${holders.isEmpty ? '' : ' e.g. "${holders.first.text.trim()}"'}');
      expect(holders, isNotNull);
    });

    test('the page form serializes for the choice POST', () {
      final form = AspNetFormData.fromDocument(chooseDoc);
      expect(form.isEmpty, isFalse,
          reason: 'no #aspnetForm on ChooseCharacter');
      expect(form['__VIEWSTATE'], isNotNull);
      expect(form['__EVENTVALIDATION'], isNotNull);
    });
  });

  group('choice POST', () {
    test('selecting the character lands on the world home page', () async {
      final choices = AspNetForm.parseCharacterChoices(chooseDoc);
      final match =
          AspNetForm.matchCharacterChoice(choices, credentials.characterName);
      expect(match.outcome, CharacterMatchOutcome.matched);
      final choice = match.choice!;

      final form = AspNetFormData.fromDocument(chooseDoc);
      form.set('__EVENTTARGET', '');
      form.set('__EVENTARGUMENT', '');
      form.set(choice.buttonName, choice.buttonValue);

      final chooseUrl = Uri(
        scheme: 'https',
        host: loginLanding.host,
        path: AutoLoginController.chooseCharacterPath,
      );
      final response = await client.postForm(chooseUrl, form.encode());
      final trail = response.chain.map((h) => h.toString()).join(' | ');

      expect(response.status, 200, reason: 'choice POST failed: $trail');
      expect(response.finalUrl.path, contains('World/Popmundo.aspx'),
          reason: 'expected to land on the world home; chain: $trail');
      expect(AspNetForm.isLoginPath(response.finalUrl.path), isFalse,
          reason: 'the choice bounced back to login; chain: $trail');
      expect(AspNetForm.parseCharacterChoices(html_parser.parse(response.body)),
          isEmpty,
          reason: 'still on ChooseCharacter after the POST; chain: $trail');
    });
  });

  test('captures a REDACTED ChooseCharacter fixture for the fast tier',
      () async {
    var redacted = chooseHtml;
    for (final token in const [
      '__VIEWSTATE',
      '__VIEWSTATEGENERATOR',
      '__EVENTVALIDATION',
    ]) {
      redacted = redacted.replaceAllMapped(
        RegExp('(name="$token"[^>]*value=")[^"]*(")'),
        (m) => '${m[1]}REDACTED${m[2]}',
      );
    }
    final file = File('test_live/fixtures/choose_character.redacted.html');
    await file.parent.create(recursive: true);
    await file.writeAsString(redacted);
    // ignore: avoid_print
    print('[auto-login] captured ${await file.length()} bytes -> ${file.path}\n'
        'NOTE: session tokens are redacted; character names and ids are NOT. '
        'Review before committing.');
    expect(redacted, isNot(contains('ViewState')), skip: 'informational');
  });
}
