import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../l10n.dart';

/// Opens the EN/PT language dialog (I18N-03).
///
/// Re-selecting the active locale just pops — [RadioListTile] ignores taps on
/// the selected value unless [RadioListTile.toggleable] is true, so the
/// active row sets that flag and treats `onChanged(null)` as confirm/close.
Future<void> showLanguageDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final active = dialogContext.locale.languageCode;
      return AlertDialog(
        key: const Key('language-dialog'),
        title: Text('language.dialogTitle'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final locale in supportedAppLocales)
              RadioListTile<String>(
                key: Key('language-option-${locale.languageCode}'),
                title: Text('language.${locale.languageCode}'.tr()),
                value: locale.languageCode,
                groupValue: active,
                toggleable: locale.languageCode == active,
                onChanged: (code) => _onSelect(dialogContext, locale, code),
              ),
          ],
        ),
      );
    },
  );
}

Future<void> _onSelect(
  BuildContext context,
  Locale locale,
  String? code,
) async {
  if (code != null && code != context.locale.languageCode) {
    await context.setLocale(locale);
  }
  if (context.mounted) Navigator.of(context).pop();
}
