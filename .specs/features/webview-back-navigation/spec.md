# WebView Back Navigation Specification

## Problem Statement

The Android system back button and the system back swipe close Popflutter instead of walking the WebView history. The Flutter Navigator has a single home route, so a pop exits the process. Players expect back to mean "previous game page."

## Goals

- [ ] System back (button or swipe) goes to the previous WebView page when history exists
- [ ] System back exits the app when the WebView has no previous page

## Out of Scope

| Feature | Reason |
| ------- | ------ |
| Closing the debug overlay on back | Overlay is not a route; not reported |
| Forward navigation | Not requested |
| Confirm-before-exit dialog | Standard Android WebView apps exit on empty history |
| Changing iOS edge-swipe WebView setting | Plugin default already allows back-forward gestures |

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --------------------- | -------------- | --------- | ---------- |
| Empty WebView history | Allow the app to exit | Matches Android default and InAppWebView docs | n (user asked for page-back, not exit UX) |
| Drawer / pushed screens | Unchanged Flutter behavior (close drawer / pop route first) | Local history and extra routes already win | y |
| Where the intercept lives | `popmundo_webview` wraps the WebView in `PopScope` | Adapter owns WebView history (AD-002) | y |

**Open questions:** none — remaining items logged as assumptions.

## User Stories

### P1: System back follows WebView history ⭐ MVP

**User Story**: As a player, I want the phone back button and back swipe to open the previous Popmundo page so that I do not get kicked out of the app mid-session.

**Why P1**: Losing the session UI on every back press makes the wrapper unusable as a game client.

**Acceptance Criteria**:

1. WHEN the user invokes system back AND the WebView can go back THEN the system SHALL call WebView `goBack` and SHALL NOT pop the Flutter home route
2. WHEN the user invokes system back AND the WebView cannot go back THEN the system SHALL allow the Flutter route to pop (app exits on the root route)
3. WHEN the user invokes system back AND the WebView is not attached THEN the system SHALL allow the route to pop
4. WHEN the WebView has history THEN `PopScope.canPop` SHALL be `false` so predictive/gesture back does not start an app-exit animation
5. WHEN the WebView has no history THEN `PopScope.canPop` SHALL be `true`

**Independent Test**: Unit tests on a fake history port (goBack called vs not); boolean mapping for `canPop`.

## Edge Cases

- WHEN `canGoBack` is true THEN `goBack` SHALL be invoked exactly once per system-back event
- WHEN `canGoBack` is false THEN `goBack` SHALL NOT be invoked

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| -------------- | ----- | ----- | ------ |
| BACK-01 | P1: history exists → WebView goBack | Execute | Verified |
| BACK-02 | P1: no history → allow exit | Execute | Verified |
| BACK-03 | P1: detached WebView → allow exit | Execute | Verified |
| BACK-04 | P1: canPop false iff history exists | Execute | Verified |

## Success Criteria

- [ ] Back with history stays in the app and shows the previous page
- [ ] Back on the first page still leaves the app
