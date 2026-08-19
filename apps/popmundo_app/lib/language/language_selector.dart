import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../l10n.dart';

/// Opens the EN/PT language dialog (I18N-03).
///
/// Re-selecting the active locale just pops. The active [RadioListTile] is
/// `toggleable` so a second tap reports `onChanged(null)`, which we treat as
/// confirm/close (I18N-03 AC4).
Future<void> showLanguageDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final active = dialogContext.locale.languageCode;
      return AlertDialog(
        key: const Key('language-dialog'),
        title: Text('language.dialogTitle'.tr()),
        content: RadioGroup<String>(
          groupValue: active,
          onChanged: (code) {
            final selectedCode = code ?? active;
            final locale = supportedAppLocales.firstWhere(
              (l) => l.languageCode == selectedCode,
            );
            _onSelect(dialogContext, locale, code);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final locale in supportedAppLocales)
                RadioListTile<String>(
                  key: Key('language-option-${locale.languageCode}'),
                  title: Text('language.${locale.languageCode}'.tr()),
                  value: locale.languageCode,
                  toggleable: locale.languageCode == active,
                ),
            ],
          ),
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
