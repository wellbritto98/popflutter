import 'package:easy_localization/easy_localization.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

/// Localized snackbar text for one step of an auto-login cycle.
///
/// Returns null for phases that need no feedback.
String? autoLoginStatusMessage(AutoLoginStatus status) {
  final character = status.characterName ?? '';
  switch (status.phase) {
    case AutoLoginPhase.detected:
      return 'autologin.cycle.detected'.tr();
    case AutoLoginPhase.authenticating:
      return 'autologin.cycle.authenticating'.tr();
    case AutoLoginPhase.choosingCharacter:
      return 'autologin.cycle.choosingCharacter'.tr(args: [character]);
    case AutoLoginPhase.done:
      return 'autologin.cycle.done'.tr(args: [character]);
    case AutoLoginPhase.failed:
      return _failureMessage(status, character);
  }
}

String _failureMessage(AutoLoginStatus status, String character) {
  switch (status.failure) {
    case AutoLoginFailure.invalidCredentials:
      return 'autologin.cycle.failedCredentials'.tr();
    case AutoLoginFailure.missingForm:
      return 'autologin.cycle.failedForm'.tr();
    case AutoLoginFailure.noCharacters:
      return 'autologin.cycle.failedNoCharacters'.tr();
    case AutoLoginFailure.characterNotFound:
      return 'autologin.cycle.failedCharacterNotFound'.tr(args: [character]);
    case AutoLoginFailure.characterAmbiguous:
      return 'autologin.cycle.failedCharacterAmbiguous'.tr(args: [character]);
    case AutoLoginFailure.serverRejected:
      return 'autologin.cycle.failedServer'
          .tr(args: [status.serverMessage ?? '']);
    case AutoLoginFailure.networkError:
    case null:
      return 'autologin.cycle.failedNetwork'.tr();
  }
}
