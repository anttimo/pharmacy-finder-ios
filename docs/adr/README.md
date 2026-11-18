# Architecture decision records

Short records of decisions a reviewer would ask "why?" about. Add new ones with the `write-adr` skill ([`.claude/skills/write-adr/SKILL.md`](../../.claude/skills/write-adr/SKILL.md)). Project rules that follow from them are in [`CLAUDE.md`](../../CLAUDE.md).

| ADR                                     | Decision                                                      | Status   | Applies to |
| --------------------------------------- | ------------------------------------------------------------- | -------- | ---------- |
| [0001](0001-pharmacy-data-source.md)    | Pharmacy data from the Fimea register, geocoded at build time | Accepted | web, iOS   |
| [0003](0003-geocoding.md)               | Digitransit behind a narrow proxy (web), Apple on iOS         | Accepted | web, iOS   |
| [0100](0100-minimal-dependencies.md)    | Apple frameworks only, iOS 17 minimum                         | Accepted | iOS        |
| [0101](0101-pharmacy-list-loading.md)   | Pharmacy list bundled with the app, live loading later        | Accepted | iOS        |
| [0102](0102-apple-maps-link.md)         | Each result opens Apple Maps                                  | Accepted | iOS        |
| [0103](0103-precise-location.md)        | Ask for a precise location once per launch                    | Proposed | iOS        |

## Numbering

- **0001–0099: shared with the web app.** The web repo ([pharmacy-finder-web](https://github.com/anttimo/pharmacy-finder-web/tree/main/docs/adr)) holds the originals. This repo keeps unchanged copies of those that apply to iOS. Change the original first, then copy it here. The web-only ADRs (0002 minimal dependencies, 0004 hosting) aren't copied.
- **0100 and up: iOS only.** A separate range, so the two repos never use the same number for different decisions.
