---
name: a11y-check
description: Accessibility review of UI changes in the iOS app. Use before finishing any feature or fix that changes what the user sees or interacts with.
---

# Accessibility check

Go through the changed UI and report every item as **pass**, **fail (fixed)**, **fail (open)** or **n/a**. Fix what you can, then report.

## Structure

- The screen title and section headings use `.accessibilityAddTraits(.isHeader)` (or are `Section` headers), so VoiceOver's rotor can jump between them.
- Each pharmacy result's details (name, distance, address, in that order) read as one element. Its phone and Maps actions are separate buttons, not only `.accessibilityAction`s, so Voice Control, Full Keyboard Access and Switch Control reach them.
- Reading order follows the visual order. Decorative images are `.accessibilityHidden(true)`.

## VoiceOver

- Every control has an accessible label from the String Catalog. Icon-only buttons always have one.
- Status changes (locating, "showing the 3 nearest pharmacies", errors) are announced once with `AccessibilityNotification.Announcement`, not by several competing announcements.
- After a search completes, VoiceOver focus moves to the results heading (`@AccessibilityFocusState`).
- Distances read naturally ("350 metres", not "350 m"): format with `Measurement` using `.wide` width for the accessibility label if the visible form is abbreviated.
- Buttons that leave the app (phone, Maps, Settings) say so in a hint.

## Visual

- Dynamic Type: check the largest accessibility size (AX5). Nothing is clipped or truncated. Rows switch to a vertical layout where needed (`ViewThatFits` or `dynamicTypeSize` checks), and the screen scrolls.
- Contrast at least 4.5:1 for text and 3:1 for controls, in light and dark mode and with Increase Contrast. Use semantic colours (`.primary`, `.secondary`, `.tint`) rather than fixed ones.
- Meaning never depends on colour alone.
- Touch targets at least 44 × 44 pt.
- Animations respect Reduce Motion (`@Environment(\.accessibilityReduceMotion)`).

## Tests

- UI tests find the new elements by accessibility label, in English.
- Previews: add one at a large accessibility Dynamic Type size and one in dark mode for each changed view.
- If Xcode's automated audit is available (`XCUIApplication().performAccessibilityAudit()`, iOS 17+), run it in a UI test on the changed screen.

## Hand-off

End with a short list of what you could not verify automatically (for example a real VoiceOver pass on a device, Voice Control or Switch Control), so a human can check it.
