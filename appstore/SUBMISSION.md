# App Store Submission Pack — Piping Database 1.0.0

Everything below is ready to paste into App Store Connect. Items marked
**[YOU]** need your Apple account or a decision only you can make.

---

## 1. App identity

| Field | Value |
|---|---|
| Bundle ID | `com.kevinbrowncodes.PipingDatabase` (already set in the project) |
| Version / Build | 1.0.0 (1) — bump the **build** number for every re-upload of 1.0.0 |
| Primary category | Reference |
| Secondary category | Utilities |
| Age rating | 4+ (no objectionable content) |
| Price | **[YOU]** — comparable apps charge $5–$15 one-time; the reference app you started from is paid |

**App name** **[YOU]**: App Store names must be globally unique and
"Piping Database" may be taken (it's close to the app that inspired this).
Have 2–3 fallbacks ready, e.g.:
- `Piping Database: Fitter Ref`
- `PipeFitter Reference`
- `Piping DB — ASME Reference`

**Subtitle** (30 chars max): `Pipe, flange & fitting specs`

## 2. Description (paste into App Store Connect)

```
The piping reference that field crews and designers actually need — every
lookup driven by a live dimensioned drawing, working entirely offline.

SEVEN MODULES
• Pipe Schedule — ASME B36.10M & B36.19M, NPS 1/8"–48", every schedule
  including stainless 5S–80S, with a built-in length calculator for
  surface area, volume, and water-filled weight
• Fittings — B16.9 butt-weld (elbows, tees, reducers, caps, stub ends)
  and B16.11 forged socket-weld & threaded, classes 3000/6000/9000
• Flanges — B16.5 Class 125–2500 plus B16.47 Series A & B through 48",
  with drilling, bolting, and weights
• Valves — B16.10 face-to-face and end-to-end for gate, globe, check,
  and ball valves, RF/BW/RTJ
• Branch Connections — MSS SP-97 Weldolet, Sockolet, Thredolet
• Line Blanks — B16.48 spectacle blinds, paddle blanks, and spacers
• Gaskets — B16.21 flat ring and full face with drilling

BUILT FOR THE FIELD
• Global search: type "2 300 wn" and jump straight to the 2" Class 300
  weld neck flange
• Tap any drawing to flip decimal ⇄ trade fractions (nearest 1/16")
• Inch/mm everywhere, NPS or DN, your choice
• Pressure–temperature ratings per class (material group 1.1)
• Bolt-up data: stud counts and sizes, torque-per-stress tables, and a
  star-pattern tightening sequence drawn for your flange's bolt count
• Feet-inch-sixteenths trade calculator with memory
• Favorites, recents, side-by-side schedule comparison, and shareable
  datasheets with standard citations
• 100% offline — nothing to sign into, nothing tracked, no ads

EVERY NUMBER VERIFIED
Dimensional data is compiled from published tables of the governing
ASME/MSS standards and locked by automated cross-checks against
independent sources. Every value cites its standard. Always verify
critical dimensions against the current standard edition before
fabrication.
```

**Promotional text** (170 chars, editable without review):
```
Pipe schedules, flanges, fittings, valves, olets, blanks & gaskets —
live dimensioned drawings, inch/mm, fractions, torque data. Fully
offline. Built for the field.
```

**Keywords** (100 chars, comma-separated, no spaces needed):
```
pipe,fitter,flange,fitting,valve,schedule,ASME,piping,weldolet,gasket,pipefitter,NPS,torque
```

## 3. Privacy

- App Privacy questionnaire: **Data Not Collected** (every category "No").
  The app has no network access, no analytics, no accounts.
- `PrivacyInfo.xcprivacy` ships in the bundle (UserDefaults CA92.1 only).
- Privacy policy URL is required even for no-collection apps. **[YOU]**:
  publish `appstore/privacy-policy.md` somewhere public — easiest is
  GitHub Pages on this repo, giving
  `https://kevinbrowncodes.github.io/piping-database/privacy-policy` —
  or paste it into any page you control.
- Support URL **[YOU]**: the GitHub repo URL works
  (`https://github.com/kevinbrowncodes/piping-database`) if you make the
  repo public, or any contact page.

## 4. Screenshots (already captured, exact required sizes)

| Set | Size | Files |
|---|---|---|
| iPhone 6.9" | 1320×2868 | `screenshots/iphone-6.9/01-home … 06-calculator` (6) |
| iPad 13" | 2064×2752 | `screenshots/ipad-13/01-home … 04-fittings` (4) |

Upload order suggestion: pipe schedule first (the hero), then home,
flanges, fittings, valves, calculator. Both sets use the 9:41 marketing
status bar. Re-shoot anytime with the commands in the repo history, or
ask me.

## 5. Review notes (paste for App Review)

```
Reference app for industrial pipefitters and piping designers. All data
is bundled; the app makes no network requests and requires no account.
No special configuration is needed for review — all seven modules are
reachable from the home list, the calculator and settings are tabs.
```

## 6. Export compliance

`ITSAppUsesNonExemptEncryption = NO` is set in the project — App Store
Connect won't ask the encryption question on upload.

## 7. Your step-by-step **[YOU]**

1. Enroll in the Apple Developer Program ($99/yr) if not already.
2. In Xcode: open the project → PipingDatabase target → Signing &
   Capabilities → check "Automatically manage signing" → select your
   Team. (This is the only project change needed.)
3. appstoreconnect.apple.com → My Apps → "+" → New App → pick the final
   name, bundle ID `com.kevinbrowncodes.PipingDatabase`, SKU e.g.
   `piping-database-001`.
4. Xcode → Product → Archive (destination "Any iOS Device") → Distribute
   App → App Store Connect → Upload.
5. In App Store Connect: paste the metadata above, upload the two
   screenshot sets, answer privacy as "Data Not Collected", add the
   privacy-policy and support URLs.
6. TestFlight the build on your own phone first (recommended), then
   Submit for Review.
7. If you re-upload 1.0.0, bump CURRENT_PROJECT_VERSION (build number)
   first — App Store Connect rejects duplicate build numbers.

## 8. Known gaps consciously shipped in 1.0

- Full accessibility/Dynamic Type audit is still on the backlog (labels
  exist on all drawings and controls; a systematic pass hasn't run).
- Gasket Class 900 rows came from a source PDF whose table is visually
  clipped (data transcribed from the text layer, flagged in the dataset).
- Star/share/info buttons exist on Pipe Schedule and Flanges; other
  modules get them in 1.1.

None of these block review.
