# Epic: Piping Database v1.0

**Goal:** A modern iPhone/iPad piping reference app (SwiftUI + SwiftData) that
covers everything the reference app does — seven lookup modules driven by live
dimensioned drawings — and surpasses it with search, favorites, comparison,
pressure–temperature ratings, bolt torque data, and export. All data rebuilt
from public ASME/MSS standards via the verified reference library
(see [RECON.md](RECON.md)); every value guarded by the test strategy in
[TESTING.md](TESTING.md).

**Definition of done for the epic:** all seven modules shipped with tested
data, the five signature UX features (drawing, fractions, units, search,
favorites) working, CI green, TestFlight build in reviewers' hands.

Sizing: S (≤ half day) · M (1–2 days) · L (3+ days). Sequence follows the
milestone order; stories within a milestone are parallelizable unless a
dependency is noted.

---

## Milestone 0 — Foundation ✅

- [x] **PD-1 · Recon & spec** — analyze reference app, document modules,
  standards map, make-it-better list. → `docs/RECON.md`
- [x] **PD-2 · Reference library** — acquire and verify data sources for all
  seven modules (catalogs + purchased ASME B16.5-2025, B16.10-2022).
- [x] **PD-3 · Project scaffold** — Xcode project (iOS 18+, iPhone/iPad),
  SwiftData models, seeding pipeline, module list, Pipe Schedule vertical
  slice with Canvas drawing; builds and runs in simulator.

## Milestone 1 — Trustworthy core (Pipe Schedule done right) ✅

- [x] **PD-4 · Full pipe dataset** (L) — complete B36.10M (NPS 1/8–48, all
  schedules incl. 160/XXS) + B36.19M stainless (5S/10S/40S/80S); seed-version
  migration. *AC: invariant + golden + count tests pass; stainless entries
  flagged with their standard.*
- [x] **PD-5 · Test target & CI** (M) — Swift Testing unit target, XCUITest
  smoke target, GitHub Actions running tests per PR. *AC: Layers 1–3 of
  TESTING.md implemented for pipe data; red CI blocks merge.* (with PD-4)
- [x] **PD-6 · First commit & repo hygiene** (S) — initial commit to `develop`,
  push, branch protection on `main`, PR flow. *(unblocks CI in PD-5)*
- [x] **PD-7 · Pipe Schedule UX completion** (M) — NPS↔DN display toggle,
  tap-any-dimension decimal⇄fraction, volume unit picker (ft³/gal/L/m³),
  keyboard dismissal, iPad/landscape layout. *AC: UI smoke tests cover each.*

## Milestone 2 — The seven modules

- [x] **PD-8 · Fittings data — butt-weld** (L) — extract Weldbend B16.9 tables
  (90/45/3R elbows, return bends, tees, reducing tees, reducers, caps, stub
  ends) with weights; extraction workflow per TESTING.md Layer 5.
- [x] **PD-9 · Fittings data — SW/threaded** (M) — Bonney Forge B16.11 tables,
  Cl. 3000/6000/9000. (independent of PD-8)
- [x] **PD-10 · Fittings module UI** (L) — end-type/type/size pickers (4th
  picker for reducing sizes), per-type Canvas drawings with dimension
  callouts, weights display. *Depends: PD-8; PD-9 pluggable after.*
- [x] **PD-11 · Flanges data + module** (L) — Weldbend Cl. 125–2500 dims,
  drilling, bolting (stud/machine bolt, wrench, weights); WN/SO/SW/TH/Blind/
  Lapped drawings; weights per bore schedule. *Check B16.47 26"+ coverage;
  pull free large-flange chart if Weldbend lacks it.*
- [x] **PD-12 · Valves data + module** (M) — B16.10-2022 face-to-face/
  end-to-end by type, class, ends; valve-outline drawings.
- [x] **PD-13 · Branch connections data + module** (M) — Bonney Forge MSS
  SP-97 olet tables; run×branch dual pickers.
- [x] **PD-14 · Line blanks data + module** (M) — B16.48 blinds/spacers
  incl. RF-thickness note from recon.
- [ ] **PD-15 · Gaskets data + module** (M) — B16.21 flat-ring/full-face from
  Lamons + drilling from flange data; FF hole count/Ø/BCD.

## Milestone 3 — Beat the original

- [x] **PD-16 · Global settings** (S) — unit system, NPS/DN, fraction display
  preference (decimal/fraction/both); per-screen override kept.
- [x] **PD-17 · Global search** (M) — tokenized queries ("2 300 wn", "sch 80
  6"), results across modules, deep-link into pre-selected state.
- [x] **PD-18 · Favorites & recents** (M) — star any selection state; recents
  auto-tracked; home-screen section. *Wired for Pipe Schedule; star buttons on
  remaining modules are a mechanical follow-up.* *(SwiftData user models — must survive
  seed migrations, tested)*
- [x] **PD-19 · Comparison view** (M) — two selections side by side with
  per-row deltas. *Shipped for pipe schedules; flange-class comparison is a
  follow-up.*
- [x] **PD-20 · P-T ratings** (M) — B16.5 pressure–temperature tables by
  material group on flange screens + standalone chart view. *(data verified
  against owned B16.5-2025)*
- [x] **PD-21 · Bolt-up & torque** (M) — per flange: stud/bolt set + wrench
  size + Weldbend/Lamons torque-vs-stress tables; torque-pattern sequence
  diagram.
- [x] **PD-22 · Trade calculator** (M) — feet-inch-sixteenths calculator with
  memory, as a proper tab (no shake gimmick); hardware-keyboard support.
- [x] **PD-23 · Share/export** (M) — text datasheet via share sheet with
  source-standard citation. *Shipped for Pipe + Flanges; PDF/image render and
  remaining modules are follow-ups.*
- [x] **PD-24 · Reorderable modules** (S) — drag-to-reorder module list,
  persisted.

## Milestone 4 — Ship

- [x] **PD-25 · Branding** (M) — app icon, accent color, display name
  decision, launch polish.
- [ ] **PD-26 · Accessibility pass** (M) — Dynamic Type, VoiceOver labels on
  drawings/dimensions, contrast audit.
- [x] **PD-27 · Help & provenance** (S) — About-this-data sheets citing
  standards (Pipe + Flanges; remaining modules are one-liners) + data-source
  table in Settings.
- [ ] **PD-28 · App Store prep** (M) — privacy manifest, screenshots,
  description, TestFlight distribution.

---

*Stretch (post-v1):* Mac Catalyst/native macOS target · Spotlight indexing ·
widgets (favorite lookups) · B16.47 Series A/B large flanges · B16.20 spiral
wound gaskets · custom user materials/densities · offline standard-update
mechanism.
