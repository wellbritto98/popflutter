@Tags(['live'])
library;

import 'package:html/parser.dart' as html_parser;
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'support/live_client.dart';
import 'support/live_config.dart';

/// Validates the login page contract against the real site, unauthenticated.
///
/// Every field name the controller overrides is asserted to exist in the
/// markup the game actually serves — the part that used to be taken on faith.
void main() {
  late LiveClient client;
  late LiveResponse response;
  late AspNetFormData form;

  setUpAll(() async {
    client = LiveClient();
    response = await client.get(Uri.parse('${HostTracker.defaultOrigin}/'));
    LiveCapture.save('login_page.html', response.body);
    form = AspNetFormData.fromDocument(html_parser.parse(response.body));
  });

  tearDownAll(() => client.close());

  test('the default origin serves an HTML page', () {
    expect(response.status, 200);
    expect(response.headers['content-type']?.first, contains('text/html'));
  });

  test('the page is recognised as a login page by the trigger logic', () {
    expect(AspNetForm.looksLikeLoginForm(response.body), isTrue);
    expect(AspNetForm.isLoginPath('/'), isTrue);
  });

  test('the form posts back to the same path', () {
    final formEl =
        html_parser.parse(response.body).getElementById('aspnetForm');
    expect(formEl, isNotNull, reason: 'AspNetFormData keys off this id');
    expect(formEl!.attributes['method']?.toLowerCase(), 'post');
    expect(formEl.attributes['action'], './',
        reason: 'controller posts to the login path it fetched');
  });

  test('all three ASP.NET tokens are present and non-empty', () {
    for (final name in const [
      '__VIEWSTATE',
      '__VIEWSTATEGENERATOR',
      '__EVENTVALIDATION',
    ]) {
      expect(form[name], isNotNull, reason: '$name missing from live page');
      expect(form[name], isNotEmpty, reason: '$name empty on live page');
    }
  });

  test('every field the controller overrides exists in the live markup', () {
    // Serialized controls: these must be in the form data.
    for (final name in const [
      r'ctl00$cphRightColumn$ucLogin$txtUsername',
      r'ctl00$cphRightColumn$ucLogin$txtPassword',
      r'ctl00$cphRightColumn$ucLogin$ddlStatus',
    ]) {
      expect(form.names, contains(name),
          reason: 'login field renamed on the live site');
    }
    // The submit is deliberately not serialized, so assert it in the markup.
    final submit = html_parser
        .parse(response.body)
        .querySelector('input[name="ctl00\$cphRightColumn\$ucLogin\$btnLogin"]');
    expect(submit, isNotNull, reason: 'btnLogin renamed on the live site');
    expect(submit!.attributes['type'], 'submit');
    expect(submit.attributes['value'], 'OK!',
        reason: 'controller posts this exact value');
  });

  test('the status dropdown still offers the five documented values', () {
    final options = html_parser
        .parse(response.body)
        .querySelectorAll(
            'select[name="ctl00\$cphRightColumn\$ucLogin\$ddlStatus"] option');
    expect(options.map((o) => o.attributes['value']).toList(),
        containsAll(<String>['0', '1', '2', '4', '3']),
        reason: 'the settings screen exposes exactly these');
    expect(form[r'ctl00$cphRightColumn$ucLogin$ddlStatus'], '0',
        reason: 'Normal is the pre-selected default');
  });

  test('whole-form serialization keeps controls a token-only body would drop',
      () {
    expect(form.names.length, greaterThan(3),
        reason: 'a token-only body would send exactly 3 fields');
    expect(form.names, contains(r'ctl00$cphRightColumn$ddlLanguage'),
        reason: 'language select is part of a real browser submit');
    for (final name in form.names) {
      expect(name, isNotEmpty);
    }
  });

  test('no submit button is serialized', () {
    final submits = html_parser
        .parse(response.body)
        .querySelectorAll('#aspnetForm input[type="submit"]')
        .map((e) => e.attributes['name'])
        .whereType<String>();
    expect(submits, isNotEmpty, reason: 'the page does have submits');
    for (final name in submits) {
      expect(form.names, isNot(contains(name)),
          reason: '$name must be set explicitly, never auto-serialized');
    }
  });

  test('the encoded body round-trips through form decoding', () {
    form.set(r'ctl00$cphRightColumn$ucLogin$txtUsername', 'someone');
    form.set(r'ctl00$cphRightColumn$ucLogin$txtPassword', 'a+b/c=d e');
    form.set(r'ctl00$cphRightColumn$ucLogin$btnLogin', 'OK!');

    final decoded = Uri.splitQueryString(form.encode());
    expect(decoded[r'ctl00$cphRightColumn$ucLogin$txtUsername'], 'someone');
    expect(decoded[r'ctl00$cphRightColumn$ucLogin$txtPassword'], 'a+b/c=d e',
        reason: 'special characters must survive encoding');
    expect(decoded['__VIEWSTATE'], form['__VIEWSTATE'],
        reason: 'the real VIEWSTATE blob contains +, / and =');
  });
}
