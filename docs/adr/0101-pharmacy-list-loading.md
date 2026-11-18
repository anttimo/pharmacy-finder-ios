# 101. Pharmacy list: the live file first, the bundled copy as fallback

- Status: Proposed (waits for the web app to publish the list at a stable URL, see "Needs from the web app")
- Date: 2026-11-18
- Applies to: iOS app

## Context

Both apps search the same file, built from the Fimea register by the web repo's `npm run build:pharmacies` ([ADR-0001](0001-pharmacy-data-source.md)). The web app picks up a rebuilt list with its next deploy. An iOS app that only bundles the file is only as fresh as its last App Store release, and users don't always update.

## Decision

On the first search after launch, the app downloads the list from the live web service. If that fails, it uses the newest list it already has. It never fails a search because the list didn't load.

1. **Live first.** `GET https://pharmacy-finder.pharmacyfinder.workers.dev/data/pharmacies.json`, with a 5 s timeout. The URL is one constant in the app. The download starts as soon as the user starts a search, in parallel with getting the location, so it rarely adds waiting time.
2. **Check it before use.** It must decode into the same shape as the bundled file and list at least half as many pharmacies (`openTotal`) as the bundled copy. A broken or truncated publish is ignored.
3. **Cache it.** A valid download is saved in the app's Caches directory and kept in memory for the rest of the session.
4. **Fallback.** On a timeout, network error or failed check, use the newer of the cached download and the bundled `pharmacies.json` (by `generatedAt`). The bundled copy is always there, so "Use my location" works offline and on first launch without a network.
5. **Show the age.** The footer shows `generatedAt` of the list in use ("Pharmacy data updated …"), as the web app does.

The request carries no location and no identifiers. The server sees the device's IP address, just as it does for every web visitor.

The bundled copy is refreshed by copying the web repo's file before a release, in a commit of its own (see `CLAUDE.md`).

### Needs from the web app

Today the live site has no stable URL for the list. Vite bundles `pharmacies.json` into a hashed JavaScript chunk, and `/pharmacies.json` gets the SPA fallback (`index.html`). The web app must serve the file as a static asset at `/data/pharmacies.json`. The simplest way is to move it to `public/data/pharmacies.json` and have the web app `fetch()` it too, instead of `import()`, so only one copy exists. That changes the web repo's ADR-0001 ("Loading") and is decided there. This ADR stays Proposed until that's live.

## Consequences

**Good**

- A list rebuilt and deployed on the web reaches iOS users without an App Store release.
- Always works: offline, on first launch and when the web service is down.

**Bad, and how we handle it**

- **One more async step.** It runs in parallel with locating, and its timeout is short. It has no error state of its own, because the fallback always exists.
- **The two apps can show different lists for a while** (an old cached or bundled list on iOS). The footer date makes the age visible, and the UI already tells people to check with the pharmacy before going.
- **The web URL becomes a contract.** The path `/data/pharmacies.json` and the JSON shape must not change without updating both apps. The size check guards against a bad publish, not a changed shape: a changed shape fails decoding, and the app falls back.

## Alternatives considered

- Bundled file only: simplest, but the list is as old as the app version the user has installed.
- Download on every launch: costs data and battery for a list that changes a few times a month.
- Fetch the Fimea register directly from the app: the register has no coordinates, and geocoding on the device would need the Digitransit key in the app ([ADR-0001](0001-pharmacy-data-source.md)).
