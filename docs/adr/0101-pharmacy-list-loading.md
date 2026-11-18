# 101. Pharmacy list: bundled with the app, live loading later

- Status: Accepted
- Date: 2026-11-18 (rewritten in place; replaces the same-day "live file first" proposal)
- Applies to: iOS app

## Context

Both apps search the same file, built from the Fimea register by the web repo's `npm run build:pharmacies` ([ADR-0001](0001-pharmacy-data-source.md)). The web app picks up a rebuilt list with its next deploy. An iOS app that only bundles the file is only as fresh as its last App Store release, and users don't always update.

How much that matters:

- The list changes slowly: a few of about 800 pharmacies open, close or move in a month.
- The web list is rebuilt by hand too (web ADR-0001, "Staleness and rerunning"). Whoever rebuilds it can copy the same file into this repo.
- The live site has no stable URL for the list. Vite bundles `pharmacies.json` into a JavaScript chunk with a hashed name (for example `/assets/pharmacies-d2jXn_14.js`). Serving it at a fixed URL needs a change in the web repo, which we want to avoid for now.

## Decision

The app reads only the copy it bundles: `pharmacy-finder-ios/Resources/pharmacies.json`.

- **Refresh:** copy the web repo's file unchanged (the command is in `CLAUDE.md`), in a commit of its own with its `generatedAt` and `openTotal` in the message. Do it whenever the web list is rebuilt, and before every release.
- **Show the age:** the footer shows the list's `generatedAt` ("Pharmacy data updated …"), as the web app does.
- **Keep the door open:** the list comes from a `PharmacyListLoader` protocol. The bundled loader is its only implementation for now. The model and views don't know where the list comes from.

Loading a bundled file can't fail in practice, so the list has no error state. A file that doesn't decode is a build mistake: a unit test decodes the bundled file and checks its count.

## Consequences

**Good**

- No network request for the list, and no change to the web app. Works offline and on first launch.
- Simple: one file read and one decode, easy to test.

**Bad, and how we handle it**

- **Stale until the next release, and longer for users who don't update.** The footer date makes the age visible, and the UI already tells people to check with the pharmacy before going. If this becomes a real problem, do "Later" below.

## Later: live loading

If freshness matters more later, without changing the web app's code:

1. **Web repo:** a small Vite plugin in `vite.config.ts` emits a copy of `src/data/pharmacies.json` as `data/pharmacies.json` in the build. Cloudflare serves it as a static asset (no Worker code runs; `run_worker_first` covers only `/api/*`). The web app keeps its `import()`. That URL and the JSON shape then become a contract between the two apps.
2. **iOS:** a second `PharmacyListLoader` that downloads `https://pharmacy-finder.pharmacyfinder.workers.dev/data/pharmacies.json` with a short timeout, rejects a file that doesn't decode or lists less than half the bundled count, caches a valid one, and otherwise falls back to the newer of the cache and the bundled copy.
3. **Optional:** a scheduled job that rebuilds and deploys the list, as described in web ADR-0001 ("Later: refresh on the server"). With 1 and 2 in place, iOS users would get it without a release.

That change gets its own ADR, superseding this one.

## Alternatives considered

- Live file first, bundled as fallback (this ADR's first version): needs a stable URL on the web app first. Deferred to "Later".
- Fetch the Fimea register directly from the app: the register has no coordinates, and geocoding on the device would need the Digitransit key in the app ([ADR-0001](0001-pharmacy-data-source.md)).
