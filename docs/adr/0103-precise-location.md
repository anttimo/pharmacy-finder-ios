# 103. Ask for a precise location once per launch

- Status: Proposed
- Date: 2026-11-18
- Applies to: iOS app

## Context

iOS's location prompt has a "Precise" switch, on by default. A user who turns it off gives the app only an approximate location, accurate to a few kilometres, until they turn it back on in Settings. In a town with several pharmacies, an approximate location can put the wrong three first, or in the wrong order.

An app can ask for a precise location for the current session with `requestTemporaryFullAccuracyAuthorization(withPurposeKey:)`. iOS shows a second prompt with the app's purpose text. The answer lasts only until the app is no longer in use, by design: the user's saved choice stays approximate.

## Decision

When a "Use my location" fix comes back approximate, the screen model asks for a precise location, **at most once per app launch**.

- **Allowed:** the app takes a new, precise fix and searches with it.
- **Declined, or the precise fix fails:** the app searches with the approximate fix anyway. The results are marked approximate, so the screen can say that the order may differ.
- Later taps in the same launch don't ask again.

The purpose text is in `Info.plist` under `NSLocationTemporaryUsageDescriptionDictionary`, key `NearestPharmacies`, translated in `Resources/InfoPlist.xcstrings`.

## Consequences

**Good**

- Users who turned Precise off still get the nearest pharmacies when they need them, with one tap.
- Their saved choice isn't changed, and declining still gives results.

**Bad, and how we handle it**

- **A second prompt right after the first** for those users. It only appears when the location is approximate, which is not the default.
- **It comes back on every launch** for users who keep Precise off. Once per launch keeps it from repeating on every tap.

## Alternatives considered

- Accept the approximate location silently: the user isn't told the results may be off.
- Accept it with a note and a button to Settings, no second prompt: respects the saved choice, but needs a trip to Settings to get exact results.
