class CharacterButton {
  const CharacterButton({required this.name, required this.value});

  final String name;
  final String value;
}

class AspNetForm {
  AspNetForm._();

  static String? extractHidden(String html, String fieldName) {
    final escaped = RegExp.escape(fieldName);
    final re = RegExp(
      'name="$escaped"[^>]*value="([^"]*)"',
      caseSensitive: false,
    );
    final m = re.firstMatch(html);
    if (m != null) return m.group(1);
    final re2 = RegExp(
      'value="([^"]*)"[^>]*name="$escaped"',
      caseSensitive: false,
    );
    return re2.firstMatch(html)?.group(1);
  }

  static Map<String, String> extractLoginTokens(String html) {
    final viewState = extractHidden(html, '__VIEWSTATE');
    final generator = extractHidden(html, '__VIEWSTATEGENERATOR');
    final validation = extractHidden(html, '__EVENTVALIDATION');
    if (viewState == null || generator == null || validation == null) {
      return {};
    }
    return {
      '__VIEWSTATE': viewState,
      '__VIEWSTATEGENERATOR': generator,
      '__EVENTVALIDATION': validation,
    };
  }

  static List<CharacterButton> findCharacterButtons(String html) {
    final re = RegExp(
      r'<input[^>]*type="submit"[^>]*name="(ctl00\$cphLeftColumn\$repCharacters\$ctl\d+\$btnChooseCharacter2)"[^>]*value="([^"]*)"',
      caseSensitive: false,
    );
    final reAlt = RegExp(
      r'<input[^>]*name="(ctl00\$cphLeftColumn\$repCharacters\$ctl\d+\$btnChooseCharacter2)"[^>]*type="submit"[^>]*value="([^"]*)"',
      caseSensitive: false,
    );
    final out = <CharacterButton>[];
    final seen = <String>{};
    for (final match in [...re.allMatches(html), ...reAlt.allMatches(html)]) {
      final name = match.group(1)!;
      final value = match.group(2)!;
      if (seen.add(name)) {
        out.add(CharacterButton(name: name, value: value));
      }
    }
    return out;
  }

  /// Matches configured [characterName] against button values like
  /// `Escolher Troy` or `Choose Troy`.
  static CharacterButton? matchCharacter(
    List<CharacterButton> buttons,
    String characterName,
  ) {
    final target = characterName.trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final button in buttons) {
      final value = button.value.trim();
      final lower = value.toLowerCase();
      if (lower == 'escolher $target' || lower == 'choose $target') {
        return button;
      }
      if (lower.endsWith(' $target') &&
          (lower.startsWith('escolher ') || lower.startsWith('choose '))) {
        return button;
      }
    }
    return null;
  }

  static bool looksLikeLoginForm(String html) {
    return html.contains('ucLogin_txtUsername') ||
        html.contains(r'ucLogin$txtUsername') ||
        html.contains('ucLogin\$txtUsername');
  }

  static bool isLoginPath(String path) {
    return path == '/' ||
        path == '/Default.aspx' ||
        path.endsWith('/Default.aspx');
  }
}
