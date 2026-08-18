# UserScript Manager Context

**Gathered:** 2026-08-17
**Spec:** `.specs/features/userscript-manager/spec.md`
**Status:** Ready for design

---

## Feature Boundary

Native UserScript manager reachable from the sidebar: import by `.user.js` URL (validate → persist → inject → reload → SnackBar), list with enable/disable Switch, delete with confirmation dialog. Material theme unchanged. No GM polyfill; unsupported headers reject the import.

---

## Implementation Decisions

### Validation / headers

- Honor every header the InAppWebView `UserScript` API can apply; reject the whole import if any header/value cannot be honored, listing them in the SnackBar.
- No extra security allowlist — installing unknown scripts is the user's risk.
- Supported grants: `none`, `unsafeWindow`, `unwrap`, or absent → `ContentWorld.PAGE`.

### Apply timing

- Auto-reload the WebView after every successful import, toggle, and delete (InAppWebView: runtime add/remove takes effect on next page load).

### UI / navigation

- ListView screen via `Navigator.push` so the WebView stays in the tree.
- Theme: existing app `ThemeData` only — no custom palette/typography.
- English copy, sentence case, active voice.
- Empty state: "No userscripts yet" + add affordance.
- Delete: `AlertDialog` confirmation; cancel is a no-op.

### Agent's Discretion

- HTTP fetcher injected (`dart:io` HttpClient in app; fake in tests); not TimedFetch.
- Catalog key `userscripts.v1` on `KeyValueStore`.
- Dedup by exact `sourceUrl`.
- `@require` fetch timeout ~20s; one import at a time (disable add while in flight).
- `groupName: 'userscript:<id>'` isolation from built-in scripts.

### Declined / Undiscussed Gray Areas → Assumptions

- See spec Assumptions table (Navigator.push, dedup, fetcher) — agent defaults, confirmed in plan.

---

## Specific References

- InAppWebView 6.x docs: Injection, Communication, User Scripts, Content Worlds
  - https://inappwebview.dev/docs/category/javascript/
  - https://inappwebview.dev/docs/webview/javascript/user-scripts/
- Context7: `/pichillilorenzo/flutter_inappwebview`, `/pichillilorenzo/inappwebview.dev`
- Sidebar extension point: `buildAppMenuItems` (AD-009)

---

## Deferred Ideas

- Auto-update via `@updateURL`
- Source editor / paste raw JS
- GM_* polyfill / Tampermonkey compatibility layer
- Per-origin allowlist UI
