import 'package:flutter/material.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'auto_login_messages.dart';

/// Surfaces an auto-login phase change as a SnackBar.
///
/// Takes the messenger rather than a `BuildContext` because the shell drives it
/// from a stream listener, above its own `Scaffold`, via a `GlobalKey`. Lives in
/// this feature's folder alongside [autoLoginStatusMessage] rather than in the
/// composition root.
///
/// Does nothing when the messenger is not mounted yet, or when the phase has no
/// user-facing message.
void showAutoLoginStatusSnackBar(
  ScaffoldMessengerState? messenger,
  AutoLoginStatus status, {
  required Color errorColor,
}) {
  if (messenger == null) return;
  final message = autoLoginStatusMessage(status);
  if (message == null) return;
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: Key('autologin-status-${status.phase.name}'),
        content: Text(message),
        backgroundColor: status.phase == AutoLoginPhase.failed
            ? errorColor
            : null,
      ),
    );
}
