[![Build Android APK](https://github.com/astrowizardteam/AstroWizard-software/actions/workflows/build_apk.yml/badge.svg)](https://github.com/astrowizardteam/AstroWizard-software/actions/workflows/build_apk.yml)

# AstroWizard Kundli (Android, Flutter)

Vedic astrology app inspired by Parashara's Light. See `docs/ANALYSIS.md` for the
analysis, calculation notes and roadmap.

**Features**: birth input (date, time to the second, place by name or coordinates),
North Indian charts (D1, D3, D9, D10), Sudarshan Chakra (D1 / D9 / transit rings),
planet table with nakshatra/pada, natural + temporal + compound friendship (Maitri),
Panchang, Ashtakavarga (BAV + SAV), Shadbala with optimum marks and % of optimum,
Bhava bala of every house, Vimshottari dasha to 5 levels (Maha, Antar, Pratyantar,
Sookshma, Prana), saved charts. Planet labels show degree plus ᴿ (retrograde) / ᶜ (combust) marks; a Ranking tab lists planets strongest to weakest. Tap any planet for aspects to/from, avasthas (Baladi, Jagradadi, Deeptadi), Jaimini chara karaka and a dominance index. Fixed conventions: Lahiri ayanamsa, mean node,
whole-sign houses. (South Indian style and PDF reports are intentionally out of scope.)

## App flow
* Home lists saved charts (open / edit / delete); **New** opens an unsaved chart.
* Chart tab (front page): D1 large, two small charts of your choice (D3 / D9 / D10 / Transit / Sudarshan; tap to enlarge), rotate-all-charts and nakshatra options, then the Vimshottari dasha tree.
* Bottom bar: Chart, Planets (Positions / Ranking / Maitri), Strength (Shadbala / Bhava / Ashtakavarga), Panchang.
* Top bar: close (asks to save if there are changes), **BTR** (birth time rectification: -/+ 1 hour, 1 minute, 1 second, with Asc, Moon nakshatra and dasha shown live), save, edit details.

## Layout
- `lib/engine/` - calculation engine (`ephemeris.dart` is the only file that touches Swiss Ephemeris)
- `lib/ui/` - input form, chart painters, result tabs
- `tools/reference_engine.py` - Python reference engine used to verify results and create `test/golden.json`
- `.github/workflows/build_apk.yml` - builds the release APK on GitHub

## Run locally
```bash
flutter create --platforms=android --project-name astrowizard_kundli --org in.co.astrowizard .
flutter pub get
flutter test
flutter run
```
`flutter create .` only generates the missing `android/` runner; it keeps our `lib/` and `pubspec.yaml`.

## Verification done
Python reference (`tools/reference_engine.py`, pyswisseph 2.10.03, Swiss Ephemeris
data files `sepl_18` / `semo_18`, Lahiri). The Dart engine is tested against its output
(`test/engine_test.dart`, golden data `test/golden.json`; regenerate with
`python tools/reference_engine.py test/golden.json`).

Audit results:
* Planet longitudes: cross-checked with astropy; ascendant with an independent formula.
* Vimshottari: 0.00 s difference vs PyJHora over 5 levels on 4 charts (same Moon longitude).
* Vargas D3/D7/D9/D10/D12/D30: identical to PyJHora on 3000 random longitudes each.
* Panchang (tithi, nakshatra, yoga, karana, vara) identical; sunrise/sunset within ~1 min.
* Ashtakavarga: BPHS tables (Moon/Mars/Jupiter rows checked against a published source);
  totals 48/49/39/54/56/52/39, SAV 337.
* Shadbala: checked component by component against the worked examples of V.P. Jain
  (13 Sep 1981) and B.V. Raman (16 Oct 1918). Uccha, Saptavargaja, Ojhayugma, Kendradi,
  Drekkana, Dig, Nathonnata, Paksha, Tribhaga, Abda, Masa, Vara, Hora, Ayana and Drik
  match within 0.5 virupa; totals within ~3 virupas (Cheshta bala is the only larger
  deviation, up to ~4 virupas, because the books use Surya-Siddhanta mean tables).
  The one outlier in the books (Raman's Mars Dig 64.3, above the 60 maximum) is a book error.

## Not yet verified
The Dart code could not be compiled in the authoring environment (no Flutter
SDK access). Expect to fix small compile/API errors on first build, especially
`sweph` plugin call signatures and the `epheAssets` paths in `lib/engine/ephemeris.dart`
(the ephemeris files live in `assets/ephe/`). Outside 1800-2400 AD Swiss Ephemeris
falls back to Moshier automatically.

## Known conventions
* Rahu/Ketu: mean node. Positions: apparent, geocentric. Houses: whole-sign.
* Dasha year = 365.25 days. Birth time is local wall-clock time with a fixed UTC offset
  chosen by the user (historical DST / pre-1947 zones are NOT looked up - enter the offset
  that was actually in force at the birth place and date).

## License note
Swiss Ephemeris is AGPL / commercial. Get the commercial license before a closed-source Play Store release.
- Chara dasha (Jaimini, K.N. Rao) tab under Dasha, 5 levels from lagna.
- Offline atlas: ~7,000 Indian towns + large world cities (`assets/cities.txt`; world cities use standard time, edit the offset for DST births).
- Backup/Restore of all saved charts via clipboard JSON (Kundli screen ⋮ menu).
- Transit: any date and time, with −/+ 1 year / month / day steps.
- Share with a friend (share icon on home screen; set kShareLink in lib/config.dart).
