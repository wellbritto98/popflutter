import 'package:html/parser.dart' as html_parser;
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

/// Trimmed copy of the live `https://www.popmundo.com/` markup: the three
/// tokens, the registration inputs, the login controls, two selects and two
/// submit buttons.
const loginPageHtml = '''
<html><body>
<form name="aspnetForm" method="post" action="./" id="aspnetForm">
  <input type="hidden" name="__VIEWSTATE" id="__VIEWSTATE" value="6FQ33Rl+X5/dpm==" />
  <input type="hidden" name="__VIEWSTATEGENERATOR" value="CA0B0334" />
  <input type="hidden" name="__EVENTVALIDATION" value="s6v/fsFjFSvW==" />
  <input name="ctl00\$cphLeftColumn\$ctl00\$txtLN" type="text" maxlength="20" />
  <input name="ctl00\$cphLeftColumn\$ctl00\$txtEM" type="text" />
  <input type="submit" name="ctl00\$cphLeftColumn\$ctl00\$btnSU" value="Register" />
  <input name="ctl00\$cphRightColumn\$ucLogin\$txtUsername" type="text" />
  <input name="ctl00\$cphRightColumn\$ucLogin\$txtPassword" type="password" />
  <select name="ctl00\$cphRightColumn\$ucLogin\$ddlStatus">
    <option selected="selected" value="0">Normal</option>
    <option value="1">Busy</option>
  </select>
  <select name="ctl00\$cphRightColumn\$ddlLanguage">
    <option value="11">Portugu&#234;s</option>
    <option selected="selected" value="2">US English</option>
  </select>
  <input type="checkbox" name="chkRemember" value="yes" />
  <input type="checkbox" name="chkTerms" value="yes" checked="checked" />
  <input type="text" name="disabledField" value="nope" disabled="disabled" />
  <input type="text" value="anonymous" />
  <input type="submit" name="ctl00\$cphRightColumn\$ucLogin\$btnLogin" value="OK!" />
</form>
</body></html>
''';

void main() {
  group('AspNetFormData.fromDocument', () {
    final form =
        AspNetFormData.fromDocument(html_parser.parse(loginPageHtml));

    test('carries every hidden token, not just __VIEWSTATE', () {
      expect(form['__VIEWSTATE'], '6FQ33Rl+X5/dpm==');
      expect(form['__VIEWSTATEGENERATOR'], 'CA0B0334');
      expect(form['__EVENTVALIDATION'], 's6v/fsFjFSvW==');
    });

    test('keeps controls a token-only body would drop', () {
      expect(form.names, contains(r'ctl00$cphLeftColumn$ctl00$txtLN'));
      expect(form[r'ctl00$cphLeftColumn$ctl00$txtLN'], '');
      expect(form[r'ctl00$cphRightColumn$ddlLanguage'], '2');
    });

    test('selects fall back to the selected option', () {
      expect(form[r'ctl00$cphRightColumn$ucLogin$ddlStatus'], '0');
    });

    test('select with no selected option uses the first', () {
      final doc = html_parser.parse(
        '<form id="aspnetForm"><select name="s">'
        '<option value="a">A</option><option value="b">B</option>'
        '</select></form>',
      );
      expect(AspNetFormData.fromDocument(doc)['s'], 'a');
    });

    test('excludes submit buttons — callers set them explicitly', () {
      expect(form.names, isNot(contains(r'ctl00$cphRightColumn$ucLogin$btnLogin')));
      expect(form.names, isNot(contains(r'ctl00$cphLeftColumn$ctl00$btnSU')));
    });

    test('includes only checked boxes, and skips disabled/nameless controls', () {
      expect(form['chkTerms'], 'yes');
      expect(form.names, isNot(contains('chkRemember')));
      expect(form.names, isNot(contains('disabledField')));
      expect(form.names.where((n) => n.isEmpty), isEmpty);
    });

    test('missing form yields an empty payload (abort signal)', () {
      final doc = html_parser.parse('<html><body><p>nope</p></body></html>');
      expect(AspNetFormData.fromDocument(doc).isEmpty, isTrue);
    });
  });

  group('set / encode', () {
    test('set replaces in place and appends when absent', () {
      final form = AspNetFormData.fromDocument(html_parser.parse(loginPageHtml));
      final before = form.names.length;
      form.set(r'ctl00$cphRightColumn$ucLogin$txtUsername', 'troyfournier');
      expect(form[r'ctl00$cphRightColumn$ucLogin$txtUsername'], 'troyfournier');
      expect(form.names.length, before, reason: 'replace must not append');

      form.set('__EVENTTARGET', '');
      expect(form.names, contains('__EVENTTARGET'));
      expect(form.names.length, before + 1);
    });

    test('set collapses duplicate names into one entry', () {
      final doc = html_parser.parse(
        '<form id="aspnetForm">'
        '<input name="dup" value="1"><input name="dup" value="2">'
        '</form>',
      );
      final form = AspNetFormData.fromDocument(doc);
      expect(form.names.where((n) => n == 'dup').length, 2);
      form.set('dup', '3');
      expect(form.names.where((n) => n == 'dup').length, 1);
      expect(form['dup'], '3');
    });

    test('encode percent-encodes \$ names and VIEWSTATE payloads', () {
      final form = AspNetFormData.fromDocument(html_parser.parse(loginPageHtml));
      form.set(r'ctl00$cphRightColumn$ucLogin$txtPassword', 'p a/s+s');
      final body = form.encode();
      expect(body, contains('ctl00%24cphRightColumn%24ucLogin%24txtPassword='));
      expect(body, contains('__VIEWSTATE=6FQ33Rl%2BX5%2Fdpm%3D%3D'));
      expect(body, isNot(contains(r'$')));
      expect(body.split('&').every((p) => p.contains('=')), isTrue);
    });
  });
}
