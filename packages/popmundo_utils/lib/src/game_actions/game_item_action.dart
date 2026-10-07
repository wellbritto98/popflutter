import 'package:html/dom.dart';

import '../autologin/aspnet_form_data.dart';
import '../scheduler/scheduler_models.dart';
import 'game_action_contracts.dart';
import 'game_forms.dart';

/// Picks only the first direct row with the exact name and a usable image.
AspNetFormData itemPost(Document document, Uri url, UseItemAction action) {
  final form = freshForm(document, url);
  final candidates = itemCandidates(document).where(
    (candidate) =>
        normalized(candidate.name).toLowerCase() ==
            normalized(action.itemName).toLowerCase() &&
        candidate.operation == action.operation,
  );
  if (candidates.isEmpty) throw const GameActionException('itemUnavailable');
  final button = candidates.first.buttonName;
  form.set('$button.x', '1');
  form.set('$button.y', '1');
  return form;
}
