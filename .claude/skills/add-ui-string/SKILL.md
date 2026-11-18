---
name: add-ui-string
description: Add or change user-facing text in the iOS app, in Finnish and English together. Use whenever a view needs new visible text, an accessibility label or hint, an alert or an error message.
---

# Add a UI string

Strings live in the String Catalog `pharmacy-finder-ios/Resources/Localizable.xcstrings`. English is the development language.

1. **Reuse first.** Search the catalog's keys before adding a new one.
2. **Name the key** by area, dot-separated, like the web app: `results.heading`, `status.denied`. Give the English text as the default value so the catalog and code read well:

   ```swift
   Text("results.heading", comment: "Heading above the list of nearest pharmacies.")
   String(localized: "status.locating", defaultValue: "Finding your location…", comment: "Announced while waiting for a location fix.")
   ```

   SwiftUI views that take a `LocalizedStringKey` (`Text`, `Button`, `Label`, `.accessibilityLabel`) look the key up automatically. Plain `String` APIs need `String(localized:)`. Never pass a literal to `Text(verbatim:)` or build text with `+`.
3. **Add both languages in the same change.** Edit the `.xcstrings` JSON directly: an `en` and an `fi` localization, both with `"state" : "translated"`. Never leave the Finnish as a copy of the English. The `LocalizationTests` unit test fails if a key lacks either language.
4. **Write natural translations, not word-for-word ones.**
   - Finnish: plain written Finnish (apteekki, aukioloajat). Reuse the web app's wording where the same text exists (`pharmacy-finder-web/src/i18n/fi.ts`).
   - Same register in both: short, calm, polite.
5. **Interpolation and plurals.** Use interpolation in the key (`Text("results.count \(count)")`) and the catalog's plural variations (`one` / `other`), not `if count == 1`. Format distances with `Measurement` and `.formatted()`, and numbers and dates with `FormatStyle`, so Finnish gets its decimal comma.
6. **Add a `comment`** that says where the string appears and what any placeholder means.
7. **Flag uncertainty.** If you're not confident in a translation, add `TODO(i18n-review)` to that key's comment and list it in your summary.
8. Build and run the unit tests.
