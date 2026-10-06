import 'package:html/dom.dart';

import '../autologin/aspnet_form_data.dart';
import '../scheduler/scheduler_models.dart';
import 'game_action_contracts.dart';
import 'game_forms.dart';

/// Revalidates the artist, offered level and optional integer-cent spending cap.
AspNetFormData crewPost(Document document, Uri url, PayCrewAction action) {
  final form = freshForm(document, url);
  final options = crewOptions(document);
  if (options.artistId != action.artistId) {
    throw const GameActionException('artistMismatch');
  }
  final bonuses = options.bonuses.where((b) => b.level == action.bonusLevel);
  final cap = action.maxCostMinor;
  if (bonuses.length != 1 || (cap != null && bonuses.single.costMinor > cap)) {
    throw const GameActionException('bonusUnavailable');
  }
  final element = document.getElementById('aspnetForm')!;
  final buttons = element
      .querySelectorAll('input[type="submit"]')
      .where(
        (button) =>
            button.attributes['name'] == cashBonusButton &&
            ownsControl(button, element) &&
            !AspNetFormData.isDisabledControl(button) &&
            (button.attributes['value'] ?? '').trim().isNotEmpty,
      );
  if (buttons.length != 1) throw const GameActionException('bonusUnavailable');
  form.set(cashBonusField, action.bonusLevel.toString());
  form.set(cashBonusButton, buttons.single.attributes['value']!);
  return form;
}
