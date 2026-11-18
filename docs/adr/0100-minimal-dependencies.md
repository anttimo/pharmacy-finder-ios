# 100. Minimal dependencies (iOS)

- Status: Accepted
- Date: 2026-11-18
- Applies to: iOS app

## Context

The app does one thing: find a location (device location or a place search) and show the nearest pharmacies as a sorted list. There is one screen, no account, no mutations and no state shared between screens.

It needs location, place search, a bundled data file and a list UI. The iOS SDK covers all of that. Every package adds build time, upgrade work and code a reviewer has to trust. The web app follows the same rule ([ADR-0002 in the web repo](https://github.com/anttimo/pharmacy-finder-web/blob/main/docs/adr/0002-minimal-dependencies.md)).

## Decision

Use only Apple's frameworks: SwiftUI, Observation, CoreLocation, MapKit and Foundation. No Swift packages.

| Usually                               | Here instead                                                                 | Why it's enough                                                                 |
| ------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Alamofire / networking layer          | None now; `URLSession` with `async`/`await` if live loading is added          | The pharmacy list ships with the app ([ADR-0101](0101-pharmacy-list-loading.md)) |
| TCA / Redux-style store               | One `@Observable` model, owned by the view, with `Task` cancellation          | One screen, no shared state                                                     |
| Navigation / coordinator library      | None                                                                         | Single screen                                                                   |
| Geocoding SDK                         | `MKLocalSearchCompleter` + `MKLocalSearch` ([ADR-0003](0003-geocoding.md))   | Built in, free, no key                                                          |
| SwiftGen / R.swift / i18n library     | A String Catalog (`Localizable.xcstrings`), fi and en                        | A few dozen strings. A unit test checks that every string has both languages    |
| Quick/Nimble, snapshot testing        | Swift Testing for unit tests, XCUITest for one smoke test per user flow      | Built into Xcode                                                                |
| SwiftLint                             | `swift-format`, which ships with Xcode (config in `.swift-format`)           | Formatting and basic lint without a separate install                            |

**Minimum iOS version: 17.0.** iOS 17 introduced the Observation framework (`@Observable`), which the app's state is built on, and `AccessibilityNotification.Announcement` for status announcements. Nothing else the app needs is newer. Raising the floor needs a reason in this ADR.

A new package needs a short ADR that supersedes or amends this one.

## Consequences

**Good**

- Small app, fast builds, and nothing to update except Xcode.
- Each piece is small enough to read and test directly.
- The model's states map one to one onto the UI states, as on the web.

**Bad, and how we handle it**

- **We own cancellation and race handling.** A new search cancels the running one (`Task.cancel()`), and tests cover a new search started while one is running.
- **The OS can be older than the SDK.** APIs newer than iOS 17 need `if #available`. The compiler enforces that.
- **String Catalog gaps don't fail the build.** Xcode only warns about missing translations, so a unit test reads the catalog and fails if a string lacks fi or en.
