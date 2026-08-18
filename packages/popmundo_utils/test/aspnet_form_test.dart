import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  const loginHtml = '''
<form>
<input type="hidden" name="__VIEWSTATE" id="__VIEWSTATE" value="VS123" />
<input type="hidden" name="__VIEWSTATEGENERATOR" id="__VIEWSTATEGENERATOR" value="CA0B0334" />
<input type="hidden" name="__EVENTVALIDATION" id="__EVENTVALIDATION" value="EV456" />
<input name="ctl00\$cphRightColumn\$ucLogin\$txtUsername" type="text" id="ctl00_cphRightColumn_ucLogin_txtUsername" />
</form>
''';

  const chooseHtml = '''
<input type="hidden" name="__EVENTTARGET" value="" />
<input type="hidden" name="__EVENTARGUMENT" value="" />
<input type="hidden" name="__VIEWSTATE" value="VSCHAR" />
<input type="hidden" name="__VIEWSTATEGENERATOR" value="5AC42ABD" />
<input type="hidden" name="__EVENTVALIDATION" value="EVCHAR" />
<input type="submit" name="ctl00\$cphLeftColumn\$repCharacters\$ctl00\$btnChooseCharacter2" value="Escolher Peter" />
<input type="submit" name="ctl00\$cphLeftColumn\$repCharacters\$ctl04\$btnChooseCharacter2" value="Escolher Troy" />
<input type="submit" name="ctl00\$cphLeftColumn\$repCharacters\$ctl05\$btnChooseCharacter2" value="Choose Violet" />
''';

  test('extractLoginTokens reads VIEWSTATE trio', () {
    final tokens = AspNetForm.extractLoginTokens(loginHtml);
    expect(tokens['__VIEWSTATE'], 'VS123');
    expect(tokens['__VIEWSTATEGENERATOR'], 'CA0B0334');
    expect(tokens['__EVENTVALIDATION'], 'EV456');
  });

  test('looksLikeLoginForm detects username field', () {
    expect(AspNetForm.looksLikeLoginForm(loginHtml), isTrue);
    expect(AspNetForm.looksLikeLoginForm('<div>hello</div>'), isFalse);
  });

  test('matchCharacter supports Portuguese and English prefixes', () {
    final buttons = AspNetForm.findCharacterButtons(chooseHtml);
    expect(buttons.length, 3);
    expect(
      AspNetForm.matchCharacter(buttons, 'Troy')?.name,
      r'ctl00$cphLeftColumn$repCharacters$ctl04$btnChooseCharacter2',
    );
    expect(
      AspNetForm.matchCharacter(buttons, 'Violet')?.value,
      'Choose Violet',
    );
    expect(AspNetForm.matchCharacter(buttons, 'Missing'), isNull);
  });

  test('isLoginPath covers home and Default.aspx', () {
    expect(AspNetForm.isLoginPath('/'), isTrue);
    expect(AspNetForm.isLoginPath('/Default.aspx'), isTrue);
    expect(AspNetForm.isLoginPath('/World/Popmundo.aspx'), isFalse);
  });
}
