import 'package:html/dom.dart';

import '../autologin/aspnet_form.dart';
import '../autologin/aspnet_form_data.dart';
import '../scheduler/scheduler_models.dart';
import 'game_action_contracts.dart';
import 'game_transaction.dart';

Element? nearestRow(Element element) {
  for (var parent = element.parent; parent != null; parent = parent.parent) {
    if (parent.localName == 'tr') return parent;
  }
  return null;
}

class OwnedCharacterChoice {
  const OwnedCharacterChoice(this.character, this.buttonName, this.buttonValue);
  final GameCharacter character;
  final String buttonName;
  final String buttonValue;
}

bool ownsControl(Element element, Element form) {
  if (element.attributes.containsKey('form') &&
      element.attributes['form'] != form.id) {
    return false;
  }
  for (var parent = element.parent; parent != null; parent = parent.parent) {
    if (parent.localName == 'form') return identical(parent, form);
  }
  return false;
}

String normalized(String value) => AspNetForm.normalizeName(value);
int? _identity(Iterable<Element> elements) {
  final list = elements.toList();
  if (list.length != 1 ||
      !RegExp(r'^[1-9][0-9]*$').hasMatch(list.single.text.trim())) {
    return null;
  }
  return int.tryParse(list.single.text.trim());
}

List<OwnedCharacterChoice> ownedChoices(Document doc) {
  final form = doc.getElementById('aspnetForm');
  if (form == null) throw const GameActionException('formUnavailable');
  final choices = <OwnedCharacterChoice>[];
  for (final box in form.querySelectorAll('div.box')) {
    final id = _identity(box.querySelectorAll('.idHolder'));
    final headings = box.querySelectorAll('h2');
    final buttons = box.querySelectorAll('input[type="submit"]');
    if (id == null || headings.length != 1 || buttons.length != 1) continue;
    final button = buttons.single;
    final name = button.attributes['name'];
    final fullName = normalized(headings.single.text);
    if (name == null ||
        name.isEmpty ||
        fullName.isEmpty ||
        AspNetFormData.isDisabledControl(button) ||
        !ownsControl(button, form)) {
      continue;
    }
    choices.add(
      OwnedCharacterChoice(
        GameCharacter(id: id, name: fullName),
        name,
        button.attributes['value'] ?? '',
      ),
    );
  }
  if (choices.isEmpty) throw const GameActionException('charactersUnavailable');
  if (choices.map((c) => c.character.id).toSet().length != choices.length) {
    throw const GameActionException('characterAmbiguous');
  }
  return choices;
}

void verifyCharacter(Document doc, int id) {
  if (_identity(doc.querySelectorAll('.charPresBox .idHolder')) != id) {
    throw const GameActionException('characterMismatch');
  }
}

String _route(String path) =>
    path.endsWith('/') ? path.substring(0, path.length - 1) : path;
AspNetFormData freshForm(Document doc, Uri url) {
  final form = doc.getElementById('aspnetForm');
  if (form == null) throw const GameActionException('formUnavailable');
  if ((form.attributes['method'] ?? '').toLowerCase() != 'post') {
    throw const GameActionException('routeMismatch');
  }
  final action = url.resolve(form.attributes['action'] ?? '');
  GameTransaction.validateUrl(action);
  if (action.origin != url.origin ||
      _route(action.path) != _route(url.path) ||
      action.hasQuery) {
    throw const GameActionException('routeMismatch');
  }
  final data = AspNetFormData.fromDocument(doc, strictDisabledControls: true);
  if (data.isEmpty) throw const GameActionException('formUnavailable');
  data.set('__EVENTTARGET', '');
  data.set('__EVENTARGUMENT', '');
  return data;
}

class ItemCandidate {
  ItemCandidate(this.name, this.buttonName);
  final String name;
  final String buttonName;
}

List<ItemCandidate> itemCandidates(Document doc) {
  final candidates = <ItemCandidate>[];
  final form = doc.getElementById('aspnetForm');
  final table = form?.querySelector('#checkedlist');
  if (table == null || form == null) return candidates;
  for (final row in table.querySelectorAll('tr')) {
    final links = row
        .querySelectorAll('a[href]')
        .where(
          (a) =>
              nearestRow(a) == row &&
              RegExp(
                r'^/World/Popmundo\.aspx/Character/ItemDetails/[1-9][0-9]*/?$',
              ).hasMatch(Uri.tryParse(a.attributes['href']!)?.path ?? ''),
        )
        .toList();
    final hidden = row
        .querySelectorAll('input[type="hidden"]')
        .where(
          (e) =>
              nearestRow(e) == row &&
              ownsControl(e, form) &&
              (e.attributes['name'] ?? '').endsWith('hidItemIDstring') &&
              !AspNetFormData.isDisabledControl(e) &&
              (e.attributes['value'] ?? '').isNotEmpty,
        )
        .toList();
    final buttons = row
        .querySelectorAll('input[type="image"]')
        .where(
          (e) =>
              nearestRow(e) == row &&
              ownsControl(e, form) &&
              !AspNetFormData.isDisabledControl(e) &&
              (Uri.tryParse(e.attributes['src'] ?? '')?.path ?? '').endsWith(
                '/Item_Use.png',
              ) &&
              (e.attributes['name'] ?? '').isNotEmpty,
        )
        .toList();
    if (links.length != 1 || hidden.length != 1 || buttons.length != 1) {
      continue;
    }
    final name = normalized(links.single.text);
    if (name.isEmpty || name.length > 120) continue;
    candidates.add(ItemCandidate(name, buttons.single.attributes['name']!));
  }
  return candidates;
}

const cashBonusField = r'ctl00$cphLeftColumn$ctl01$ddlCashBonus';
const cashBonusButton = r'ctl00$cphLeftColumn$ctl01$btnCashBonus';
GameCrewOptions crewOptions(Document doc) {
  final id = _identity(
    doc.querySelectorAll('.entityLogo.gameimage.idTrigger .idHolder'),
  );
  if (id == null) throw const GameActionException('artistUnavailable');
  final title = normalized(doc.querySelector('title')?.text ?? '');
  final titleMatch = RegExp(r'^(?:\([0-9]+\)\s*)?Popmundo - (.+)$')
      .firstMatch(title);
  if (titleMatch == null) throw const GameActionException('artistUnavailable');
  final name = normalized(titleMatch.group(1)!);
  final form = doc.getElementById('aspnetForm');
  if (form == null) throw const GameActionException('formUnavailable');
  final selects = form
      .querySelectorAll('select')
      .where(
        (e) =>
            e.attributes['name'] == cashBonusField &&
            ownsControl(e, form) &&
            !AspNetFormData.isDisabledControl(e),
      )
      .toList();
  final bonuses = <GameBonusChoice>[];
  if (selects.length == 1) {
    final seenLevels = <int>{};
    for (final option in selects.single.querySelectorAll('option')) {
      final level = int.tryParse(option.attributes['value'] ?? '');
      if (level == null || level < 14 || level > 20) continue;
      if (!seenLevels.add(level)) {
        throw const GameActionException('bonusUnavailable');
      }
      if (AspNetFormData.isDisabledControl(option)) continue;
      final match = RegExp(
        r'^([^0-9]+?)\s+([0-9]{1,3}(?:\.[0-9]{3})*|[0-9]+),([0-9]{2})\s+M\$$',
      ).firstMatch(normalized(option.text));
      if (match == null) continue;
      final major = BigInt.tryParse(match.group(2)!.replaceAll('.', ''));
      if (major == null) continue;
      final minor =
          major * BigInt.from(100) + BigInt.from(int.parse(match.group(3)!));
      if (minor <= BigInt.zero || minor > BigInt.parse('9223372036854775807')) {
        continue;
      }
      bonuses.add(
        GameBonusChoice(
          level: level,
          label: match.group(1)!,
          costMinor: minor.toInt(),
        ),
      );
    }
  }
  if (bonuses.map((b) => b.level).toSet().length != bonuses.length) {
    throw const GameActionException('bonusUnavailable');
  }
  return GameCrewOptions(artistId: id, artistName: name, bonuses: bonuses);
}
