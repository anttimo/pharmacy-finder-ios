---
name: write-adr
description: Record an architecture decision as a short ADR in docs/adr/. Use when choosing or changing a dependency, data source, iOS version, state approach or anything a reviewer would ask "why?" about, or when a change would contradict an existing ADR.
---

# Write an ADR

1. **Read first.** Read [`docs/adr/README.md`](../../../docs/adr/README.md) and any ADR your decision touches. Don't contradict an accepted ADR silently: supersede it (step 7).
2. **Shared or iOS only?**
   - **Shared with the web app** (data source, geocoding, anything both apps must agree on): the original lives in the web repo, numbered 0001–0099. Write or change it there with that repo's `write-adr` skill, then copy it here unchanged with the "Mirrored from the web app" note on top (see the existing copies). Tell the user that the web repo changes too.
   - **iOS only:** number it 0100 or up. List `docs/adr/` and take the next number after the highest one in that range. Filename: `NNNN-short-kebab-title.md`.
3. **Get today's date** with `date +%F`. Don't guess it.
4. **Use this template** (it matches the existing ADRs):

   ```markdown
   # N. Title as a decision ("Use X for Y")

   - Status: Proposed
   - Date: YYYY-MM-DD
   - Applies to: iOS app

   ## Context
   The problem and the forces at play. What would break or be harder without a decision.

   ## Decision
   What we do, stated plainly. Include the key details (API, URL, iOS version) a reader needs.

   ## Consequences
   **Good**
   - ...

   **Bad, and how we handle it**
   - ...

   ## Alternatives considered
   - Option: why not, in one line.
   ```

   If the options compare well in a table (as in ADR 0100), put the table in Context or Decision and drop "Alternatives considered". When a decision is revisited later, add a dated "Revisited" section instead of rewriting history.

5. **Keep it short:** about one screen. Write it for a reviewer who wasn't in the conversation. Prefer concrete reasons over general principles.
6. **Status stays `Proposed`** until the user accepts it. Then change it to `Accepted`.
7. **Superseding:** if this replaces an earlier ADR, set the old one's status to `Superseded by NNNN` and link both ways.

   **Exception before the first release:** until the app has shipped to users, an ADR whose decision changes may be rewritten in place instead. Put the new date in its header with a note of what it replaces, and keep the old decision and why it was dropped in a short "Rejected: …" section. Once the app is released, always supersede.
8. **Cross-reference.**
   - Link related ADRs with relative links, for example `[ADR-0003](0003-geocoding.md)`. Link web-only ADRs with their GitHub URL.
   - Add a row for it to the table in `docs/adr/README.md`.
   - If it changes a rule in [`CLAUDE.md`](../../../CLAUDE.md) (stack, ground rules, scope), update that rule and link the ADR there.
