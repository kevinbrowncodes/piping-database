# Testing Plan

This is a reference-data app: the worst possible bug is a wrong number rendered
confidently. The plan is therefore data-first — most of the suite guards the
dataset and the formulas; UI tests are a thin smoke layer on top.

Stack: **Swift Testing** (`@Test`/`#expect`) for units, **XCUITest** for UI smoke,
in-memory `ModelContainer` for anything touching SwiftData.

## Layer 1 — Seed data integrity (the core)

Unit tests that run against the bundled seed JSON on every build:

- **Schema**: decodes cleanly; no duplicate size or size×schedule pairs; every
  entry carries a source standard.
- **Physical invariants** (catch transcription typos structurally):
  - OD strictly increases with NPS; wall > 0 and < OD/2; ID > 0.
  - STD wall == Sch 40 wall for NPS ≤ 10; XS == Sch 80 for NPS ≤ 8.
  - Heavier schedule ⇒ thicker wall at the same size.
  - NPS ≥ 14 ⇒ OD == NPS exactly; NPS ↔ DN mapping is the standard one.
- **Golden values**: a curated fixture table of known-true values
  (e.g. 1/2" Sch 40 wall = 0.109, 6" OD = 6.625, 8" Sch 80 = 0.500), typed
  **independently from the seed, from a different source document**. Double-entry
  bookkeeping: the seed comes from one reference, goldens from another, so a
  transcription error has to happen twice, identically, to slip through.
- **Completeness counts**: each size lists its expected schedule set; per-module
  row counts match the source table's row count.

The same pattern extends to every future dataset (fittings, flanges, valves…):
schema + invariants + independently-sourced goldens + counts.

## Layer 2 — Formulas & derived values

- Plain-end weight `10.69(OD−t)t` reproduces the published B36.10M weight
  column within rounding (±0.5%).
- **Reference-app parity regressions**: the values validated from the original
  app's screenshots (1/8" Sch 10 → W 0.19 lb/ft, Ww 0.22 lb/ft,
  volume 0.000514 ft³/ft, Ext SA 0.11 ft²) locked in as regression tests.
- Unit conversions: in↔mm, lb/ft↔kg/m, ft³↔L exact factors; formatted output
  round-trips sanely.
- Fraction display (when built): decimal ⇄ nearest-sixteenth conversions,
  including exact halves and values that don't land on a sixteenth.
- Edge cases: zero/negative length input, entry with missing size relationship,
  smallest (1/8") and largest sizes.

## Layer 3 — SwiftData & seeding

- Seeding is idempotent: run twice ⇒ no duplicates (fetch counts stable).
- Seed-version bump migrates: old data replaced, user data (favorites, recents)
  preserved once those exist.
- All against in-memory containers; no test touches the real store.

## Layer 4 — UI smoke (XCUITest)

- Launch → every module row present; tap each available module → screen appears.
- Pipe Schedule: pick size + schedule → all data labels non-empty and match the
  golden value for that pick; unit toggle flips in→mm everywhere at once.
- Debug-only launch-environment hooks (compiled out of Release):
  `OPEN_MODULE=<id|payload>` deep-links into a module, `OPEN_TAB` selects a
  tab, and `UITEST_RESET=1` clears the `PrefKey.all` preferences plus the
  SavedLookup store for deterministic runs — every UI test must set it
  (the `launchApp` helper in SmokeTests does).
- Optional later: snapshot tests on the Canvas drawings to catch dimension
  callouts drifting or overlapping.

## Layer 5 — Extraction workflow checks (process, not code)

When extracting a table from a reference PDF:
1. Extract to JSON.
2. Structural invariants + counts must pass (Layer 1 machinery).
3. Spot-verify ~10% of rows against the PDF page image, plus a second
   independent source where available (e.g. Weldbend vs. metric edition vs.
   ASME copy).
4. Transcribe goldens for that table from the *other* source, lock in.

## CI

GitHub Actions (repo already on GitHub): `xcodebuild test` on an iOS Simulator
destination for every PR to `develop`/`main`. Data tests are fast (no UI), so
they gate every commit; UI smoke can run on a schedule or pre-release if CI
minutes matter.
