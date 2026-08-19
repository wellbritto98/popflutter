import 'package:html/parser.dart' as html_parser;
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

/// ChooseCharacter shape: one `div.box` per character, full name in the `<h2>`,
/// first name only in the submit `value`. The first two boxes deliberately
/// share a first name — that collision is what full-name matching fixes.
const chooseCharacterHtml = r'''
<html><body>
<form id="aspnetForm">
  <input type="hidden" name="__VIEWSTATE" value="VS" />
  <input type="hidden" name="__VIEWSTATEGENERATOR" value="5AC42ABD" />
  <input type="hidden" name="__EVENTVALIDATION" value="EV" />

  <div class="box">
    <h2>Choose a character</h2>
    <p>Pick one to continue.</p>
  </div>

  <div class="box">
    <h2><a href="/World/Popmundo.aspx/Character/111">Deon Drinkwater</a></h2>
    <input type="submit" name="ctl00$cphLeftColumn$repCharacters$ctl00$btnChooseCharacter2" value="Escolher Deon" />
  </div>

  <div class="box">
    <h2>
       Deon   Fairweather
    </h2>
    <input type="submit" name="ctl00$cphLeftColumn$repCharacters$ctl01$btnChooseCharacter2" value="Escolher Deon" />
  </div>

  <div class="box">
    <h2>Ren&#233;e S&#227;o Louren&#231;o</h2>
    <input type="submit" name="ctl00$cphLeftColumn$repCharacters$ctl02$btnChooseCharacter2" value="Choose Renée" />
  </div>
</form>
</body></html>
''';

const duplicateNameHtml = r'''
<html><body><form id="aspnetForm">
  <div class="box">
    <h2>Deon Drinkwater</h2>
    <input type="submit" name="ctl00$cphLeftColumn$repCharacters$ctl00$btnChooseCharacter2" value="Escolher Deon" />
  </div>
  <div class="box">
    <h2>Deon Drinkwater</h2>
    <input type="submit" name="ctl00$cphLeftColumn$repCharacters$ctl01$btnChooseCharacter2" value="Escolher Deon" />
  </div>
</form></body></html>
''';

void main() {
  final choices =
      AspNetForm.parseCharacterChoices(html_parser.parse(chooseCharacterHtml));

  group('parseCharacterChoices', () {
    test('skips boxes without a submit button', () {
      expect(choices.length, 3);
      expect(choices.map((c) => c.fullName),
          isNot(contains('Choose a character')));
    });

    test('reads the full name through a nested link', () {
      expect(choices.first.fullName, 'Deon Drinkwater');
    });

    test('collapses whitespace in a pretty-printed heading', () {
      expect(choices[1].fullName, 'Deon Fairweather');
    });

    test('decodes HTML entities in the heading', () {
      expect(choices[2].fullName, 'Renée São Lourenço');
    });

    test('captures the button name and value', () {
      expect(choices.first.buttonName,
          r'ctl00$cphLeftColumn$repCharacters$ctl00$btnChooseCharacter2');
      expect(choices.first.buttonValue, 'Escolher Deon');
    });
  });

  group('matchCharacterChoice', () {
    test('distinguishes characters sharing a first name', () {
      final drinkwater =
          AspNetForm.matchCharacterChoice(choices, 'Deon Drinkwater');
      final fairweather =
          AspNetForm.matchCharacterChoice(choices, 'Deon Fairweather');

      expect(drinkwater.outcome, CharacterMatchOutcome.matched);
      expect(fairweather.outcome, CharacterMatchOutcome.matched);
      expect(drinkwater.choice!.buttonName, endsWith(r'ctl00$btnChooseCharacter2'));
      expect(fairweather.choice!.buttonName, endsWith(r'ctl01$btnChooseCharacter2'));
    });

    test('is case- and whitespace-insensitive', () {
      final match =
          AspNetForm.matchCharacterChoice(choices, '  deon   DRINKWATER ');
      expect(match.outcome, CharacterMatchOutcome.matched);
      expect(match.choice!.fullName, 'Deon Drinkwater');
    });

    test('a first name alone no longer matches', () {
      expect(
        AspNetForm.matchCharacterChoice(choices, 'Deon').outcome,
        CharacterMatchOutcome.notFound,
      );
    });

    test('unknown and empty names are notFound', () {
      expect(
        AspNetForm.matchCharacterChoice(choices, 'Nobody Here').outcome,
        CharacterMatchOutcome.notFound,
      );
      expect(
        AspNetForm.matchCharacterChoice(choices, '   ').outcome,
        CharacterMatchOutcome.notFound,
      );
    });

    test('two boxes with the same full name are ambiguous, never guessed', () {
      final dupes = AspNetForm.parseCharacterChoices(
          html_parser.parse(duplicateNameHtml));
      final match =
          AspNetForm.matchCharacterChoice(dupes, 'Deon Drinkwater');
      expect(match.outcome, CharacterMatchOutcome.ambiguous);
      expect(match.choice, isNull);
    });
  });

  group('page detection', () {
    test('looksLikeLoginForm spots the username control', () {
      expect(
        AspNetForm.looksLikeLoginForm(
            '<input id="ctl00_cphRightColumn_ucLogin_txtUsername">'),
        isTrue,
      );
      expect(AspNetForm.looksLikeLoginForm(chooseCharacterHtml), isFalse);
    });

    test('isLoginPath covers root and Default.aspx', () {
      expect(AspNetForm.isLoginPath('/'), isTrue);
      expect(AspNetForm.isLoginPath('/Default.aspx'), isTrue);
      expect(AspNetForm.isLoginPath('/World/Popmundo.aspx'), isFalse);
    });
  });
}
