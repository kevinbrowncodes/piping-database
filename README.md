# Piping Database

A modern iPhone/iPad piping reference app — SwiftUI + SwiftData, iOS 18+.

Seven lookup modules driven by live dimensioned drawings, plus the features
field users actually ask for: global search, favorites & recents, schedule
comparison, pressure–temperature ratings, bolt-up torque data, a
feet-inch-sixteenths trade calculator, and datasheet export with standard
citations.

| Module | Standard |
|---|---|
| Pipe Schedule | ASME B36.10M · B36.19M |
| Fittings (BW + SW/TH) | ASME B16.9 · B16.11 |
| Flanges (½–48″) | ASME B16.5 · B16.47 A/B |
| Valves | ASME B16.10 |
| Branch Connections | MSS SP-97 |
| Line Blanks | ASME B16.48 |
| Gaskets | ASME B16.21 |

## Data integrity

Every dataset is compiled from published manufacturer catalogs that reprint
the governing standards, then verified three ways (see
[docs/TESTING.md](docs/TESTING.md)):

1. Structural invariants (ODs increase with NPS, walls physically sane,
   bolt circles inside flange ODs, …) checked at extraction time and in CI.
2. Golden values transcribed from *different* sources than the extraction —
   double-entry bookkeeping for engineering data.
3. Reference-app parity regressions for computed values.

`xcodebuild test` runs the full suite; GitHub Actions gates every PR.

## Project docs

- [docs/RECON.md](docs/RECON.md) — reference-app analysis and source library
- [docs/BACKLOG.md](docs/BACKLOG.md) — epic and story status
- [docs/TESTING.md](docs/TESTING.md) — the testing strategy
- `tools/gen_pipe_seed.py` — pipe dataset generator with built-in validation

## Building

Open `PipingDatabase.xcodeproj` in Xcode 16+ and run. No dependencies, no
network access — everything ships in the bundle.

*Always verify critical dimensions against the current edition of the
governing standard before fabrication.*
