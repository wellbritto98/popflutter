# App Shell Internationalization (EN + PT) Context

**Gathered:** 2026-08-18
**Spec:** `.specs/features/app-i18n/spec.md`
**Status:** Ready for design

---

## Feature Boundary

Internationalize the native app shell of `apps/popmundo_app` (sidebar menu, Userscripts screen, Auto Login screen, Android keepalive notification) in English + Portuguese using easy_localization, including a manual EN/PT selector in the sidebar. Debug overlay internals, package exception messages, game WebView content, and platform launcher labels stay out.

---

## Implementation Decisions

### Escopo do DebugOverlay (discussed)

- DebugOverlay internals stay **English** — dev-only tool; no keys added for 'host:', 'network', 'console', 'clear', 'run', hints.
- `BackgroundStatus` telemetry labels ('running', 'granted', '12s ago'…) remain computed English values — debug surface.
- The sidebar *menu item* that opens the panel ("Debug panel" label + subtitle) IS translated, since it lives in the menu registry with the other items.

### Notificação do keepalive em segundo plano (discussed)

- `notificationTitle` and `notificationText` of the Android FGS are translated from the catalog at service start.
- `channelId`, `channelName`, `channelDescription` remain the existing English constants (channel is created once per install; A3).
- A bundled English default applies if translations are not yet resolvable (A8).

### Seleção de idioma (discussed)

- A **"Language"/"Idioma" item in the sidebar** (always visible, debug and release) opens a dialog listing exactly **English** and **Português**.
- Initial locale follows the device (pt\* → PT, otherwise EN fallback); the explicit choice overrides and persists across restarts.
- No "follow system default" entry in the MVP (A2).

### Agent's Discretion

- Translation key naming and JSON structure (namespaced flat-nested keys planned: `common.*`, `menu.*`, `userscripts.*`, `autologin.*`, `keepalive.*`, `language.*`, `app.*`).
- Exact PT copy (best-effort native pt-BR; game status terms per A5).
- Test harness shape (a `pumpLocalized` helper in `apps/popmundo_app/test/`).
- Dialog widget layout (radio list with endonyms "English"/"Português").

### Declined / Undiscussed Gray Areas → Assumptions

None declined — the three detected gray areas were all discussed and resolved. Remaining choices are logged as spec assumptions A1, A4, A5, A6, A8.

---

## Specific References

- User explicitly named the library: **Easy Localization** ("Podemos usar o Easy Localization"). Grounded to `easy_localization 3.0.8` (latest stable on pub.dev, Dart `<4.0.0`, MIT) via the pub.dev API and the package README (web_search/context7 unavailable in this session).
- User asked for a hardcoded-string sweep of the project as the source of the catalog — done by full read of every `apps/popmundo_app/lib/**` UI file (inventory in the plan; packages excluded per A4).

---

## Deferred Ideas

- "Follow system default" selector entry (would need saved-locale reset semantics).
- Additional languages (es, it, …) — catalog format already supports drop-in files.
- Launcher label / `CFBundleDisplayName` localization via platform resources.
- Localized mapping of `popmundo_utils` import/parse error categories at the app layer (would need error codes instead of message strings).
- In-app translation completeness check / missing-key lint in CI.
