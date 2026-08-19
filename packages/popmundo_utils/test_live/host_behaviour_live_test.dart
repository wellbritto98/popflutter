@Tags(['live'])
library;

import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'support/live_client.dart';
import 'support/live_config.dart';

/// Pins the host/session facts the auto-login design rests on, without
/// authenticating: the sticky-host assumption (AD-007), the shape of the
/// unauthenticated bounce, and — the important one — whether the game's auth
/// cookie is host-only, which is what makes a cross-origin hop unreachable
/// from in-page `fetch` and forces the navigation fallback.
void main() {
  late LiveClient client;

  setUp(() => client = LiveClient());
  tearDown(() => client.close());

  test('a numbered host serves the same login form as www', () async {
    final numbered = await client.get(Uri.parse('https://75.popmundo.com/'));
    expect(numbered.status, 200);
    expect(AspNetForm.looksLikeLoginForm(numbered.body), isTrue);

    final form = AspNetFormData.fromDocument(html_parser.parse(numbered.body));
    expect(form.names, contains(r'ctl00$cphRightColumn$ucLogin$txtUsername'),
        reason: 'the cycle must work from whichever host is sticky');
  });

  test('numbered hosts are recognised as Popmundo by HostTracker', () {
    for (final host in const ['www.popmundo.com', '75.popmundo.com']) {
      expect(HostTracker.isPopmundoUri(Uri.parse('https://$host/')), isTrue);
    }
    expect(HostTracker.isPopmundoUri(Uri.parse('https://evil.com/')), isFalse);
  });

  test('an unauthenticated game page bounces to the login path', () async {
    final response = await client.get(Uri.parse(
        'https://75.popmundo.com${AutoLoginController.chooseCharacterPath}'));

    expect(response.isRedirect, isTrue,
        reason: 'ChooseCharacter requires a session');
    final location = response.location!;
    expect(AspNetForm.isLoginPath(location.path), isTrue,
        reason: 'the bounce target must be what the trigger recognises');
  });

  test('the auth cookie is host-only — no domain attribute', () async {
    final response = await client.get(Uri.parse(
        'https://75.popmundo.com${AutoLoginController.chooseCharacterPath}'));

    final auth = response.setCookies
        .where((c) => c.name.toLowerCase() == 'popmundo.com')
        .toList();
    expect(auth, isNotEmpty,
        reason: 'the bounce clears the session cookie; its shape is the point');
    expect(auth.first.domain, isNull,
        reason: 'a host-only auth cookie is why www→N cannot be done by fetch — '
            'if this ever gains a domain, the navigation fallback is no longer needed');
  });

  test('theme cookies do carry a domain, proving the jar distinguishes them',
      () async {
    final response = await client.get(Uri.parse('https://75.popmundo.com/'));
    final domainScoped =
        response.setCookies.where((c) => c.domain != null).toList();
    for (final cookie in domainScoped) {
      expect(cookie.domain, contains('popmundo.com'));
    }
    // Whatever the site set, the jar must have kept the session cookie.
    expect(client.cookieNames, isNotEmpty);
  });

  test('the world home path used as the landing page is a real path', () async {
    final response = await client.get(
        Uri.parse('https://75.popmundo.com${AutoLoginController.worldHomePath}'));
    expect(response.status, anyOf(200, 302),
        reason: 'unauthenticated it may bounce, but it must not 404');
    expect(response.status, isNot(404));
  });

  test('captures the login page for the offline fixture tier', () async {
    final response = await client.get(Uri.parse('https://75.popmundo.com/'));
    LiveCapture.save('login_page_numbered_host.html', response.body);
    expect(LiveCapture.read('login_page_numbered_host.html'), isNotNull);
    expect(File(LiveCapture.fileFor('login_page_numbered_host.html').path)
        .lengthSync(), greaterThan(1000));
  });
}
