# Recon: Reference App Analysis

Working notes from screenshots of the reference piping database app (iOS, mirrored via iPhone Mirroring). This doc is the foundation for our own spec — we recreate the *functionality* from public ASME/ASTM/MSS standards; nothing is copied from the app itself.

## App structure

**Navigation:** Flat module list ("Piping Design Modules") + 4-tab bar: Settings, Modules, Help, Calculator.

**Signature UI pattern (used by every module):**
- Top: CAD-style 2D line drawing of the selected component with live dimension callouts (green dimension lines, cyan centerlines, white part outline on black).
- Unit toggle in the nav bar (`in` — presumably toggles to `mm`).
- Info (ⓘ) button per screen.
- Bottom: skeuomorphic metallic picker wheels (2–4 columns) that drive the drawing/data above. Columns are hierarchical: end-connection / type / class / size.
- Values that don't apply show as "N/A".

## Modules observed

| Module | Contents shown | Governing standards |
|---|---|---|
| **Fittings** | Elbows (90°, 45°, 90° 3D), Tee, Cross, Coupling, Cap, Reducer, Lap Joint stub; end types BW/SW/TH. Shows center-to-end dim (L), socket depth (S), and weights per Sch 40/80 | ASME B16.9 (butt-weld), B16.11 (socket-weld & threaded) |
| **Flanges B16.5** | WN, SW, SO, TH, Blind, Lapped; Classes 150–2500 | ASME B16.5 |
| **Valves** | Gate, Globe, Check, Ball, Control; ends FL/BW/SW/TH; picker includes class+facing (150 RF, 150 RJ, 300 RF…); shows face-to-face dim | ASME B16.10 |
| **Pipe Schedule** | Wrought + stainless; STD/XS/XXS + Sch 5–160; NPS↔DN toggle; shows OD, wall, ID, weight (W), water-filled weight (Ww); **embedded calculator**: enter length → ext/int/total surface area + volume with unit picker | ASME B36.10M, B36.19M |
| **Branch Connections** | Weldolet, Sockolet, Thredolet; STD/XS/XXS/3000/6000; run size × branch size pickers; shows olet height | MSS SP-97 |
| **Line Blanks** | Figure-8, Paddle Blank, Paddle Spacer; class+facing picker (150 RF…600 RF); shows OD, web/center distance, thickness t, t incl. RF thickness, hole Ø | ASME B16.48 |
| **Gaskets B16.21** | Standard picker: B16.5 / B16.47 Series A / B16.47 Series B; size × class; shows gasket ID, OD for flat-ring (FR) and full-face (FF); for FF: hole count, bolt hole Ø, BCD | ASME B16.21 (+ B16.5/B16.47 bolt patterns) |

Not yet captured: whatever the "…" picker entries expand to, and any modules below Gaskets in the scroll.

## Settings, Calculator, Help (captured)

**General Settings:**
- Nominal Ø: NPS / DN segmented toggle (global).
- Unit: inch / mm segmented toggle (global), with documented per-screen override (the `in`/`mm` nav-bar button on each module).
- "Use calculator on shake" toggle — shake gesture shows/hides the calculator from anywhere.
- Rate button, contact link. Screen is plain light gray — visually inconsistent with the rest of the app.

**Calculator tab — feet-inch-fraction trade calculator:**
- Display in feet-inches (`0'-0"`), dedicated fraction keys in sixteenths (¹⁄₁₆ … ¹⁵⁄₁₆), a `feet` key, memory (mr/m+/m−/mc), `Conv` (unit/format conversion), settings gear. This is a pipefitter's construction calculator, not a generic one.

**Help reveals two interaction features:**
- **Reorderable modules** — tap-and-hold 3 s on the module list enters edit mode with drag handles (field users put their most-used module on top).
- **Tap any dimension on a drawing to toggle decimal ↔ fraction** (29.50 ⇄ 29 ½). Applies to every dimension callout.

**Flange detail payload (visible in Help's example, a large WN flange):**
- Dimensions: OD, bolt-circle Ø, hub Ø, length-through-hub, flange thickness.
- Bolting: No. of bolts, stud Ø × length, machine bolt Ø × length, **wrench size**, total bolt-set weight.
- Flange weight listed **per bore schedule** (e.g. Sch 20 / 40 / 80 weights).

## Data model implications

- Everything keys off **NPS** (with DN equivalents) — a shared `NominalSize` axis across all modules.
- Second axes vary per module: **schedule/wall class** (pipe, fittings, olets), **pressure class + facing** (flanges, valves, blanks, gaskets), **end connection** (fittings, valves), **run×branch pair** (olets, reducing fittings — the Fittings screen has a 4th, sometimes-empty picker column for the second size of reducers/reducing tees).
- Per-record payloads are small dimension sets (2–8 named dims + weight). N/A is a real state (e.g. socket depth on a BW fitting).
- Pipe Schedule doubles as a calculator: derived values (ID, areas, volume, weights) computed from OD + wall + length + density — not stored.

## Weaknesses to beat (make-it-better list)

1. **Dated UI** — iOS-6-era metallic picker wheels, fixed black theme, static feel. Ours: native SwiftUI, adaptive light/dark, modern pickers/segmented controls, but keep the *good* idea: live dimensioned drawing driven by selection.
2. **No search** — you can't type "2 inch 300# WN flange"; you scroll wheels. Ours: global search + `@Query`-driven filtering.
3. **No favorites/recents** — field users look up the same handful of items daily.
4. **No comparison** — e.g. Sch 40 vs 80 side by side, or Class 150 vs 300 bolt patterns.
5. **iPhone-only layout** — no iPad/Mac support. Ours: `NavigationSplitView`, one codebase for iPhone/iPad/Mac.
6. **Unit toggle is per-screen** — should be global with per-value override, and show both on demand.
7. **No export/share** — sharing a datasheet as text/PDF/image is an obvious field need.
8. **Opaque provenance** — no citation of standard + edition per value. Ours: every record carries its source standard.
9. **No pressure–temperature ratings** — B16.5 P-T tables by material group are a natural add.
10. **Has bolt dimensions but no torque** — flange screens include stud/bolt sizes, counts, wrench size, and bolt weight (good!), but no torque/tension tables per gasket type. That's our add.
11. **Calculator is hidden behind a shake gesture** — cute, but undiscoverable and useless on iPad/Mac. Ours: proper tab + hardware-keyboard support, same feet-inch-sixteenths engine.
12. **Fraction display is per-tap only** — tap-to-toggle is great, but there should also be a global display preference: decimal / fraction / both.

## Worth keeping (the app's genuinely good ideas)

- Live dimensioned drawing driven by selection — the core UX.
- Tap a dimension to flip decimal ⇄ fraction.
- Feet-inch-sixteenths trade calculator with memory.
- Global unit + NPS/DN setting with per-screen override.
- User-reorderable module list.
- Flange bolting data (count, stud/machine bolt dims, wrench size, bolt-set weight) and weights per bore schedule.

## Local reference library (`references/`, git-ignored)

| File | Contents | Feeds module |
|---|---|---|
| `weldbend-american.pdf` | Weldbend 63rd ed. — B16.9 fittings (pp. 25–83, all schedules + weights), B16.5 flanges Cl. 125–2500 (pp. 84–105, incl. calculated weights); technical section: steel pipe dims (pp. 138–143), flange P-T ratings (p. 161), bolt-length method (p. 159), bolt torque (pp. 170–172), RTJ facings (p. 148), fitting P-T ratings B31.1/B31.8 (pp. 109–128) | Fittings (BW), Flanges, Pipe, P-T, bolt-up |
| `bonney-forge-forged-steel-fittings.pdf` | Bonney Forge Forged Steel Fittings & Unions — B16.11 socket-weld + threaded fittings, Cl. 3000/6000/9000, dims + weights | Fittings (SW/TH) |
| `weldbend-metric.pdf` | Same catalog, metric edition | mm values cross-check |
| `bonney-forge-branch-connections.pdf` | Bonney Forge official BC catalog — MSS SP-97 olet dimensions | Branch Connections |
| `lamons-gasket-handbook.pdf` | Lamons Gasket & Fastener Handbook — B16.21/B16.20 gasket data + **bolt torque tables** | Gaskets, bolt-up/torque feature |
| `ASME B16.5-2025 … .pdf` | Official ASME B16.5-2025 (purchased) — P-T ratings by material group, flange dims NPS ½–24 Cl. 150–2500, bolt-length method (App. C), gasket limits (App. B). License note: use as verification reference; extract primary data from catalogs | Flanges P-T ratings, bolt-up (verification) |
| `ASME B16.10-2022 … .pdf` | Official ASME B16.10-2022 standard (purchased) — authoritative valve face-to-face/end-to-end | Valves (primary) |
| `valve-face-to-face-b16-10-chart.pdf` | Global Supply Line B16.10 chart — gate/globe/ball/swing-check, Cl. 150–2500, RF/BW/RTJ, in+mm | Valves (cross-check) |
| `spectacle-blind-b16-48-datasheet.pdf` | dwpiping datasheet — B16.48 blinds & spacers, ID/OD/thk/weights per class, in+mm | Line Blanks |

## Reference data sources (public)

- ASME B36.10M / B36.19M — pipe dimensions & weights
- ASME B16.9 / B16.11 — fitting dimensions
- ASME B16.5 / B16.47 A&B — flange dimensions, drilling, P-T ratings
- ASME B16.10 — valve face-to-face / end-to-end
- ASME B16.48 — line blanks
- ASME B16.21 / B16.20 — gaskets
- MSS SP-97 — branch connection fittings (olets)
