import 'package:html/dom.dart';

import 'auto_login_trace.dart';

/// One character offered on `/World/Popmundo.aspx/ChooseCharacter`.
///
/// The page renders one `div.box` per character: the `<h2>` holds the **full**
/// name, while the submit button's `value` only carries the first name
/// (`Escolher Deon` / `Choose Deon`). Matching on the button value therefore
/// collides between characters that share a first name — the full name from the
/// `<h2>` is the identifier, and [buttonName] is what the POST needs.
class CharacterChoice {
  const CharacterChoice({
    required this.fullName,
    required this.buttonName,
    required this.buttonValue,
  });

  /// `<h2>` text, trimmed and whitespace-collapsed, entities decoded.
  final String fullName;

  /// `name` attribute of the box's submit, e.g.
  /// `ctl00$cphLeftColumn$repCharacters$ctl00$btnChooseCharacter2`.
  final String buttonName;

  /// `value` attribute of that submit, e.g. `Escolher Deon`.
  final String buttonValue;
}

enum CharacterMatchOutcome { matched, notFound, ambiguous }

class CharacterMatch {
  const CharacterMatch._(this.outcome, this.choice);

  const CharacterMatch.matched(CharacterChoice choice)
      : this._(CharacterMatchOutcome.matched, choice);
  const CharacterMatch.notFound() : this._(CharacterMatchOutcome.notFound, null);
  const CharacterMatch.ambiguous()
      : this._(CharacterMatchOutcome.ambiguous, null);

  final CharacterMatchOutcome outcome;
  final CharacterChoice? choice;
}

class AspNetForm {
  AspNetForm._();

  /// Reads one [CharacterChoice] per `div.box` that has both an `<h2>` and a
  /// submit button. Boxes without both (the page also renders informational
  /// boxes) are skipped.
  static List<CharacterChoice> parseCharacterChoices(Document doc) {
    final out = <CharacterChoice>[];
    for (final box in doc.querySelectorAll('div.box')) {
      final heading = box.querySelector('h2');
      final submit = box.querySelector('input[type="submit"]');
      if (heading == null || submit == null) continue;
      final buttonName = submit.attributes['name'];
      if (buttonName == null || buttonName.isEmpty) continue;
      // `.text` walks nested nodes (the h2 usually wraps an <a>) and decodes
      // entities, matching `h2.textContent.trim()` on the page side.
      final fullName = normalizeName(heading.text);
      if (fullName.isEmpty) continue;
      out.add(CharacterChoice(
        fullName: fullName,
        buttonName: buttonName,
        buttonValue: submit.attributes['value'] ?? '',
      ));
    }
    return out;
  }

  /// Exact full-name match, case- and whitespace-insensitive.
  ///
  /// Two boxes with the same full name yield [CharacterMatchOutcome.ambiguous]
  /// so the caller can abort instead of silently picking the first one.
  static CharacterMatch matchCharacterChoice(
    List<CharacterChoice> choices,
    String fullName,
  ) {
    final target = normalizeName(fullName).toLowerCase();
    if (target.isEmpty) return const CharacterMatch.notFound();
    final hits = [
      for (final c in choices)
        if (c.fullName.toLowerCase() == target) c,
    ];
    if (hits.isEmpty) return const CharacterMatch.notFound();
    if (hits.length > 1) return const CharacterMatch.ambiguous();
    return CharacterMatch.matched(hits.first);
  }

  /// Trims and collapses internal whitespace (the `<h2>` is often pretty
  /// printed across lines).
  static String normalizeName(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Describes what a page actually contains, so a failed character match can
  /// be diagnosed from a log instead of guessing at the markup.
  ///
  /// Reports the structures the parser depends on (`div.box`, `h2`, submit
  /// inputs) plus looser variants, because the app's WebView may be served a
  /// different theme than a desktop browser.
  static List<String> describeDocument(Document doc) {
    final lines = <String>[];

    final title = doc.querySelector('title')?.text.trim() ?? '<no title>';
    lines.add('title: $title');
    lines.add('body classes: '
        '${doc.querySelector('body')?.attributes['class'] ?? '<none>'}');

    final forms = doc.querySelectorAll('form');
    lines.add('forms: ${forms.length} '
        '${forms.map((f) => f.id.isEmpty ? '<no id>' : f.id).toList()}');

    lines.add('div.box: ${doc.querySelectorAll('div.box').length}');
    lines.add('.box (any tag): ${doc.querySelectorAll('.box').length}');
    lines.add('[class*=box]: '
        '${doc.querySelectorAll('[class]').where((e) => (e.attributes['class'] ?? '').toLowerCase().contains('box')).length}');

    final headings = doc.querySelectorAll('h1, h2, h3');
    lines.add('headings: ${headings.length}');
    for (final h in headings.take(30)) {
      lines.add('  <${h.localName} class="${h.attributes['class'] ?? ''}"> '
          '"${visibleName(normalizeName(h.text))}"');
    }

    final submits = doc.querySelectorAll('input[type="submit"]');
    lines.add('input[type=submit]: ${submits.length}');
    for (final s in submits.take(30)) {
      lines.add('  name="${s.attributes['name'] ?? '<none>'}" '
          'value="${visibleName(s.attributes['value'] ?? '')}"');
    }

    final buttons = doc.querySelectorAll('button');
    lines.add('<button> elements: ${buttons.length}');
    for (final b in buttons.take(20)) {
      lines.add('  type="${b.attributes['type'] ?? ''}" '
          'name="${b.attributes['name'] ?? '<none>'}" '
          'text="${visibleName(normalizeName(b.text))}"');
    }

    final imageInputs = doc.querySelectorAll('input[type="image"]');
    lines.add('input[type=image]: ${imageInputs.length}');
    for (final b in imageInputs.take(20)) {
      lines.add('  name="${b.attributes['name'] ?? '<none>'}" '
          'alt="${visibleName(b.attributes['alt'] ?? '')}"');
    }

    final chooseButtons = doc
        .querySelectorAll('input, button')
        .where((e) => (e.attributes['name'] ?? '').contains('ChooseCharacter'))
        .toList();
    lines.add('inputs named *ChooseCharacter*: ${chooseButtons.length}');
    for (final b in chooseButtons.take(30)) {
      lines.add('  type="${b.attributes['type'] ?? ''}" '
          'name="${b.attributes['name']}" '
          'value="${visibleName(b.attributes['value'] ?? '')}"');
    }

    final characterLinks = doc
        .querySelectorAll('a[href]')
        .where((a) => (a.attributes['href'] ?? '').contains('/Character/'))
        .toList();
    lines.add('links to /Character/: ${characterLinks.length}');
    for (final a in characterLinks.take(20)) {
      lines.add('  href="${a.attributes['href']}" '
          'text="${visibleName(normalizeName(a.text))}"');
    }

    return lines;
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
