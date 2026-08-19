# language (`popmundo_app`)

Seletor EN/PT da shell. Spec: `app-i18n`. AD-014. Constantes: `lib/l10n.dart`.

## Objetivo

Trocar o locale da UI nativa de release. DebugOverlay permanece em inglês.

## Responsabilidade principal

Dialog com `RadioListTile` toggleable; `context.setLocale` (Easy Localization persiste). Re-tocar o idioma ativo só fecha.

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `language_selector.dart` | `showLanguageDialog` — keys `language-dialog`, `language-option-en` / `pt` |
| `../l10n.dart` | `supportedAppLocales`, `kTranslationsPath`, `fallbackAppLocale` (`en`) |

Catálogos: `assets/translations/en.json`, `pt.json`. `main.dart`: `useOnlyLangCode`, `useFallbackTranslations`.

## Dependências

`easy_localization`. Item `language` em `buildAppMenuItems`.

## Relacionados

Toda string de release no app deve usar `.tr()`. Packages utils/webview sem locale.

## Pontos de entrada

`_openLanguage()` em `app.dart`. Locale inicial = dispositivo, senão fallback `en`.

## Observações e débitos

- Testes desligam `saveLocale` (`test/localization_helpers.dart`) para determinismo.
- `CFBundleLocalizations` no iOS inclui `en` e `pt`.
