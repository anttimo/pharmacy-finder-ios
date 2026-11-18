# 102. Each result opens Apple Maps

- Status: Accepted
- Date: 2026-11-18
- Applies to: iOS app

## Context

The web app links each result to a Google Maps search for the pharmacy's name and address ([ADR-0001](0001-pharmacy-data-source.md), "Map link"). That listing usually shows opening hours, which our data doesn't have. On iOS, Apple Maps is always installed, and it also shows the pharmacy's place card with opening hours and directions.

## Decision

Each result has a "Show in Maps" button that opens Apple Maps with an `MKMapItem` for the pharmacy: its name, address and the coordinates from our list. Like the web link, nothing is sent until the user taps it, and the user's location isn't passed to Maps by us.

## Consequences

**Good**

- Native: opens the Maps app directly, with directions one tap away. No link to a third-party web page.

**Bad, and how we handle it**

- **Apple Maps may match a different place card**, or none, for a small pharmacy. The pin is still at our coordinates with our name and address, so the user can still get there. The "check opening hours with the pharmacy" note stays.
- **Users who prefer Google Maps** can't choose it. Acceptable for a demo; revisit if people ask.
