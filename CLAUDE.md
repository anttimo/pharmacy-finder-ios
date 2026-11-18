# Nearest pharmacy (iOS)

Finds the pharmacies nearest to the user, or to a place they search for, in Finland. Single screen, SwiftUI. The pharmacy list is the web app's file, built from Fimea's pharmacy register ([ADR 0001](docs/adr/0001-pharmacy-data-source.md)). The app ships a copy of it ([ADR 0101](docs/adr/0101-pharmacy-list-loading.md)). It finds the nearest pharmacies on the device. Place search uses Apple's `MKLocalSearchCompleter` ([ADR 0003](docs/adr/0003-geocoding.md)).

**Scope:** Finland only, in Finnish and English. **Iteration 1:** "Use my location". **Iteration 2:** place search.

## Stack

- SwiftUI + Observation, Swift 6 language mode, iOS 17.0 minimum ([ADR 0100](docs/adr/0100-minimal-dependencies.md)). The target defaults to `@MainActor` isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION`).
- Swift Testing for unit tests, XCUITest for smoke tests. `swift-format` (ships with Xcode, config in `.swift-format`).
- The Xcode project uses synchronized folders: a file added under `pharmacy-finder-ios/` joins the app target automatically. Don't hand-edit `project.pbxproj` unless a build setting changes.

## Commands

Run from the repository root. `-derivedDataPath build` keeps build output in the gitignored `build/`.

- Build: `xcodebuild -project pharmacy-finder-ios.xcodeproj -scheme pharmacy-finder-ios -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build`
- Unit tests: the same, with `test -only-testing:pharmacy-finder-iosTests` instead of `build`
- UI tests: the same, with `test -only-testing:pharmacy-finder-iosUITests`. Run them after changing a user flow.
- Lint: `xcrun swift-format lint --strict -r pharmacy-finder-ios pharmacy-finder-iosTests pharmacy-finder-iosUITests`
- Format: `xcrun swift-format format -i -r pharmacy-finder-ios pharmacy-finder-iosTests pharmacy-finder-iosUITests`
- Refresh the bundled pharmacy list: `cp ../../pharmacy-finder-web/src/data/pharmacies.json pharmacy-finder-ios/Resources/pharmacies.json`. Never edit the file by hand. Commit it on its own, with the `generatedAt` and `openTotal` in the message, so it doesn't bloat a feature PR. `.gitattributes` marks it as generated.

Before saying a task is done, run lint, the build and the unit tests, and report the results.

## Ground rules

- **Apple frameworks only.** No Swift packages. Adding one needs asking first and an ADR ([ADR 0100](docs/adr/0100-minimal-dependencies.md)). APIs newer than iOS 17 need `if #available` with a fallback.
- **Structure.**
  - `Model/`: pure logic (`Pharmacy`, distance, `nearest`, formatting). No SwiftUI, no I/O. Fully unit tested.
  - `Services/`: the edges: pharmacy list loading, location, place search. Each is a small protocol with a live implementation, so tests and previews use fakes.
  - `Features/`: SwiftUI views and the `@Observable` model that drives the screen. The model gets its services in its initializer. Views hold no logic beyond layout.
  - `Resources/`: `pharmacies.json`, `Localizable.xcstrings`.
- **State.** One `@Observable` model with an explicit state enum: `idle | locating | loading | results | denied | locationError`, plus `noMatches | searchError` for place search. A new search cancels the running one. No Combine.
- **Opening hours** aren't in the data. Don't show or compute an "open now" status. Show the phone number and the "check opening hours with the pharmacy" note.
- **Location UX.** Ask for permission only when the user taps "Use my location", never at launch. When-in-use permission only, never Always. Use one location fix, not continuous updates. The user's location never leaves the device: the nearest search is local, and place search isn't biased by the user's location (it uses a Finland-wide region). No IP geolocation. Once place search exists, the field is always visible: it covers denied permission and checking another area.
- **Pharmacy list** comes from the bundled file through the `PharmacyListLoader` protocol, so live loading can be added later without touching the model or views ([ADR 0101](docs/adr/0101-pharmacy-list-loading.md)). The list has no error state of its own.
- **No hard-coded UI text.** Every visible string, accessibility label and hint goes through `Localizable.xcstrings` with Finnish and English. Use the `add-ui-string` skill. The app follows the device language and iOS's per-app language setting. No in-app language switcher.
- **Accessibility is a requirement, not polish.** VoiceOver labels on every control, results read as one element per pharmacy, status changes announced with `AccessibilityNotification.Announcement`, Dynamic Type up to the largest accessibility sizes without clipping, 44 × 44 pt touch targets, and Reduce Motion respected. Run the `a11y-check` skill before finishing any UI work.
- **Every async state has UI:** idle, locating, loading, results, location denied (with a button to open Settings), location error with retry, and for place search no matches and search error.
- **Healthcare tone.** Plain, calm and short. Never claim the list is complete or that a pharmacy is definitely open. Wherever results appear, show the "check opening hours with the pharmacy" note. The footer always shows:
  - the data source: "Pharmacy data source: Finnish Medicines Agency (Fimea) / THL CodeServer (Kanta Services)" / "Apteekkitietojen lähde: Lääkealan turvallisuus- ja kehittämiskeskus Fimea / THL Koodistopalvelu" ([ADR 0001](docs/adr/0001-pharmacy-data-source.md))
  - when the list in use was generated
  - the Digitransit credit and the OpenStreetMap ODbL notice. The pharmacy coordinates were geocoded with Digitransit, so their licences apply on iOS too ([ADR 0003](docs/adr/0003-geocoding.md)).
- **Each result** shows the name, address, straight-line distance, a tappable phone number and a "Show in Maps" button that opens Apple Maps ([ADR 0102](docs/adr/0102-apple-maps-link.md)). Three results, no distance limit.

## Decisions

Architecture decisions live in `docs/adr/` (index: [docs/adr/README.md](docs/adr/README.md)). 0001–0099 are copies of the web app's shared ADRs: change the original in the web repo first. 0100 and up are iOS only. Read the relevant ADRs before changing anything structural. Don't silently contradict an accepted ADR: propose a superseding one with the `write-adr` skill, and update the ADR index and any rule in this file that changes.

## Working style

- Keep changes small and focused, with one concern per commit. Work on a branch, never directly on `main`.
- Test behaviour, not implementation. Unit tests drive the model through fake services. UI tests find elements by accessibility label, never by position, and use a fixed location instead of real permission prompts.
- Swift 6 concurrency errors are fixed properly (actor isolation, `Sendable` types), never silenced with `@unchecked Sendable` or `nonisolated(unsafe)` without a comment explaining why it's safe.
- If a requirement is unclear or two rules conflict, ask instead of guessing.
