# Scheduled Game Actions — Context

Gathered: 2026-10-05. Status: user review pending.

## User decisions already given

- Extend the working scheduler, starting with usarItem and pagarEquipe.
- Translate the supplied Puppeteer/webscraping functions into requests, sharing repeated helpers.
- Protect the visible game screen from automated character switching.
- Investigate a second hidden WebView; native HTTP in the scheduler is explicitly acceptable if it is unsuitable.
- Submit a local notification every time a scheduled game action starts.
- Use the embedded browser for live mapping. Test credentials are private session input and never part of these files.
- Initial mapping target: Troy Drinkwater, artist black panties.
- Prior scheduler decisions persist: work in background and after reboot; skip missed occurrences without replay.
- User explains that an independent second browser login does not end the first session. This is the intended isolation model; a second WebView sharing the first jar does not reproduce it.

## Clarification in progress

One async question was sent: select item by exact name/first usable unit, or by a specific instance ID. No answer has been received at the time this draft is written. The spec transparently proposes exact name/first usable unit for replenishable consumables; revise if the user chooses otherwise.

## Proposed defaults for review

Use native HTTP with its own login and empty jar, not a hidden shared-cookie WebView. Reuse saved Auto Login credentials while binding each rule to its account and target character. Preserve artist identity, require explicit crew bonus and cap current price at the selected quote. One item use per occurrence. Abort gameplay if mandatory start notification cannot be submitted. Surface unavailable/uncertain separately; never retry a possibly applied POST. These defaults are not recorded as approved decisions yet.

## Scope exclusions

Remaining supplied functions and multi-account profile management are future features. No bonus payment or item use has been submitted during mapping. Production implementation, architectural AD amendment, tasks and independent verifier await the concrete design review.
