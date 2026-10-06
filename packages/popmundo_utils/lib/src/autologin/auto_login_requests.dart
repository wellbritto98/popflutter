import 'package:html/dom.dart';

import 'aspnet_form.dart';
import 'aspnet_form_data.dart';

/// Builds the two POST bodies of an auto-login cycle.
///
/// Extracted so the live E2E tier drives the exact same code the controller
/// runs — a test that rebuilt these bodies by hand would validate a copy, not
/// the shipped behaviour.
class AutoLoginRequests {
  AutoLoginRequests._();

  static const usernameField = r'ctl00$cphRightColumn$ucLogin$txtUsername';
  static const passwordField = r'ctl00$cphRightColumn$ucLogin$txtPassword';
  static const statusField = r'ctl00$cphRightColumn$ucLogin$ddlStatus';
  static const loginButtonField = r'ctl00$cphRightColumn$ucLogin$btnLogin';
  static const loginButtonValue = 'OK!';

  /// Whole `#aspnetForm` of the login page plus the credential overrides.
  ///
  /// Returns an empty payload when the page carries no form, which callers
  /// treat as an abort.
  static AspNetFormData loginBody(
    Document loginPage, {
    required String username,
    required String password,
    required int status,
    bool strictDisabledControls = false,
  }) {
    final form = AspNetFormData.fromDocument(
      loginPage,
      strictDisabledControls: strictDisabledControls,
    );
    if (form.isEmpty) return form;
    form.set('__EVENTTARGET', '');
    form.set('__EVENTARGUMENT', '');
    form.set(usernameField, username.trim());
    form.set(passwordField, password);
    form.set(statusField, '$status');
    // Submit buttons are never serialized, so the game's postback needs this
    // set by hand.
    form.set(loginButtonField, loginButtonValue);
    return form;
  }

  /// Whole `#aspnetForm` of the ChooseCharacter page plus the selected
  /// character's button, reproducing the game's own postback payload.
  static AspNetFormData chooseCharacterBody(
    Document choosePage,
    CharacterChoice choice,
  ) {
    final form = AspNetFormData.fromDocument(choosePage);
    if (form.isEmpty) return form;
    form.set('__EVENTTARGET', '');
    form.set('__EVENTARGUMENT', '');
    form.set(choice.buttonName, choice.buttonValue);
    return form;
  }
}
