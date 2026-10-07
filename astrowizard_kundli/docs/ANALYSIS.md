# Parashara's Light (Parashar Lite) - Analysis & Roadmap

Source: public web material about Parashara's Light (GeoVision Software), BPHS
(Brihat Parashara Hora Shastra) and standard Jyotish practice. The software
itself is closed source; this is a feature/calculation analysis, not a copy.

## 1. What Parashara's Light does

| Area | Details |
|---|---|
| Birth chart | Rasi (D1) with houses, lagna, planets, nakshatra/pada, retrogression, North / South / East Indian chart styles |
| Vargas | 16 divisional charts of Parashara (D1, D2, D3, D4, D7, D9, D10, D12, D16, D20, D24, D27, D30, D40, D45, D60), plus others |
| Dasha | Vimshottari (main), Ashtottari, Yogini, Chara (Jaimini), Shodashottari and other conditional dashas; levels up to pratyantar and deeper |
| Strength | Shadbala, Bhava Bala, Ashtakavarga (Bhinna / Sarva) |
| Yogas | Large library of classical yogas |
| Panchang | Tithi, Nakshatra, Yoga, Karana, Vara; sunrise/sunset; Hora, Choghadiya |
| Varshaphal | Annual (Tajaka) charts, Muntha, Sahams, Mudda dasha |
| Transits | Gochara, Sade Sati, ingress tables |
| Other | Upagrahas (Gulika, Mandi), Arudha padas, Karakamsa, Jaimini karakas, KP, compatibility (Ashtakoot), muhurta (separate product), interpretive reports, built-in atlas, multi-language |

## 2. Core calculation pipeline

1. **Time**: local birth time -> UTC using the time-zone offset -> Julian Day (UT).
2. **Planets**: Swiss Ephemeris tropical longitudes for Sun..Saturn, mean (or true) node.
3. **Ayanamsa**: subtract Lahiri (Chitra Paksha) ayanamsa -> sidereal longitudes.
   Ketu = Rahu + 180 deg. Retrograde = negative speed.
4. **Lagna**: ascendant from sidereal house calculation at birth lat/lon.
5. **Houses**: Whole-sign (Parashari default); each sign = one house from lagna.
6. **Nakshatra**: 27 x 13 deg 20'; pada = quarter (3 deg 20').
7. **Vimshottari**: Moon's nakshatra lord starts the sequence
   (Ketu 7, Venus 20, Sun 6, Moon 10, Mars 7, Rahu 18, Jupiter 16, Saturn 19,
   Mercury 17 = 120 years). Balance at birth = unelapsed fraction of the
   nakshatra. Antardasha length = mahadasha years x lord years / 120.
   Year length 365.25 days.
8. **Vargas**: sign-division formulas per BPHS (e.g. D9 navamsa = 3 deg 20' parts).

## 3. Phase plan for this app

Scope decisions (owner): North Indian chart style only; no PDF reports.

| Phase | Scope | Status |
|---|---|---|
| 1 | Birth input (to the second), offline city list, Lahiri sidereal planets, lagna, planet table, saved charts | **Built** |
| 2 | North Indian charts D1, D3, D9, D10; Panchang; Ashtakavarga (BAV + SAV); Shadbala; Vimshottari to 5 levels (Prana); Sudarshan Chakra; Maitri; Bhava bala | **Built** |
| 3 | More vargas (D2, D4, D7, D12, D16, D20, D24, D27, D30, D40, D45, D60), Yogas, Transits, Sade Sati, other dasha systems (Yogini, Ashtottari, Chara), ayanamsa choice | Planned |
| 4 | Ashtakoot matching, Hindi UI, full world atlas, Varshaphal, KP | Planned |

### Calculation notes for Phase 2

* **Birth time** is taken as HH:MM:SS; dasha boundaries are computed to the
  microsecond so the finest level (Prana) is exact.
* **Vimshottari levels**: Maha, Antar, Pratyantar, Sookshma, Prana. Each
  child period = parent length x lord years / 120, starting from the parent's lord.
  Year length 365.25 days.
* **Vargas** (Parashara): D3 = same / 5th / 9th sign for each 10 deg part;
  D9 = 3 deg 20' parts counted continuously from Aries; D10 = odd signs start from
  the sign itself, even signs from the 9th.
* **Panchang**: tithi / karana from Moon-Sun elongation (12 deg / 6 deg), yoga from
  Sun+Moon (13 deg 20'), vara of the Vedic day (changes at sunrise). Sunrise and
  sunset use the NOAA equations (verified within 1 minute of Swiss Ephemeris).
* **Ashtakavarga**: BPHS bindu tables; totals verified (48, 49, 39, 54, 56, 52,
  39 per planet; Sarvashtakavarga always 337).
* **Shadbala** (virupas): Sthana (Uccha, Saptavargaja, Ojhayugma, Kendradi,
  Drekkana), Dig, Kala (Nathonnata, Paksha, Tribhaga, Abda, Masa, Vara, Hora,
  Ayana), Cheshta, Naisargika, Drik. Required totals: Sun 390, Moon 360, Mars 300,
  Mercury 420, Jupiter 390, Venus 330, Saturn 300.

### Bhava bala, Maitri, Sudarshan

* **Bhava bala** = Bhavadhipati bala (Shadbala total of the house lord) + Bhava dig bala
  (house madhya vs the strongest point of its sign class: nara = lagna, jalachara = 4th,
  chatushpada = 10th, keeta = 7th) + Bhava drishti bala (benefic minus malefic aspects on
  the madhya, one quarter). Madhya = lagna degree in each sign. Optimum shown as 7 rupas.
* **Maitri**: natural (BPHS) + temporal (planet in 2/3/4/10/11/12 from another = friend)
  = compound (panchadha).
* **Sudarshan Chakra** as specified by the owner: three rings (D1, D9, transit) sharing the
  birth lagna as house 1.

### Planet detail sheet (tap a planet)

* Aspects: sign-based graha drishti (all 7th; Mars 4/8, Jupiter 5/9, Saturn 3/10; nodes 5/7/9),
  listed both ways (to / from) with sphuta drishti virupas for the seven planets.
* Avasthas: Baladi (6-degree parts, reversed in even signs), Jagradadi (by dignity),
  Deeptadi (by dignity; combust = Kopita); dignity uses exaltation / own sign / compound maitri.
* Chara karaka: 7-planet and 8-planet (with Rahu) Jaimini schemes by degree in sign.
* Dominance index (app-defined, 0-100): Shadbala 40 + Ashtakavarga bindus 20 + dignity 20 + net aspects 20.

### Shadbala method and known limits

Validated against the worked examples of V.P. Jain and B.V. Raman:

1. Moolatrikona is sign-level (45 virupas anywhere in the sign).
2. Abda / Masa lords: ahargana from the Kali epoch (360-day year, 30-day month), on the Vedic day.
3. Ayana bala: declination from the sayana longitude (ecliptic latitude ignored);
   Mercury, Moon, Saturn use (23.45 - decl), others (23.45 + decl); Sun doubled.
4. Sun and Moon have no Cheshta bala (as in the books). BPHS text equates them with
   Ayana / Paksha bala; change `ch = 0.0` in `shadbala.dart` / `reference_engine.py` if
   Parashara's Light turns out to follow that variant.
5. Drik bala: BV Raman sphuta drishti table, special aspects of Mars (+15), Jupiter (+30),
   Saturn (+45) are added; Mercury benefic when alone / with more benefics; Moon benefic while waxing.
6. Not included: Yuddha bala (planetary war, at most about 1 virupa).
7. Cheshta bala uses modern mean heliocentric longitudes; the books (Surya Siddhanta tables)
   differ by up to ~4 virupas for Mercury / Venus.
8. Whole-sign houses are used for Kendradi bala (not bhava-chalit).

## 4. Licensing caution

* Swiss Ephemeris: AGPL or paid Professional License. A closed-source / Play
  Store monetised app needs the commercial license.
* Do not copy Parashara's Light's interpretive text, UI artwork or code; write
  original content (or use classical public-domain translations).

## Jaimini Chara dasha (K.N. Rao method)
- Sequence from the lagna sign; direct if the 9th sign from lagna is odd-footed, else reverse.
- Years = count from sign to its lord's sign (forward for odd-footed, backward for even-footed) − 1; 0 → 12; +1 if the lord is exalted, −1 if debilitated (Rahu exalted Taurus, Ketu Scorpio).
- Scorpio (Mars/Ketu) and Aquarius (Saturn/Rahu): lord in the sign itself → other rules; else more conjunctions, Jupiter/Mercury/dispositor support, exaltation, dual>fixed>movable, advanced degree.
- Antardashas = parent/12, starting from the parent sign in the same direction; second cycle uses 12 − years. These two are conventions, schools differ.
- Cross-check vs PyJHora: differences remain only where PyJHora treats Mercury in Virgo as non-exalted, uses Gemini/Sagittarius as extra node exaltation signs, and counts the lagna as a conjunct in the co-lord rule.

## Shodashvarga, Vimshopaka, dasha browser (v-next)
- 16 vargas (D1 2 3 4 7 9 10 12 16 20 24 27 30 40 45 60) follow Parashara's rules; the 11 new/changed ones were cross-checked against PyJHora on 300 random longitudes each (0 mismatches). Golden file regenerated for all 16.
- Vimshopaka bala is the app's own implementation (weights sum to 20; dignity points 20/18/15/10/7/5 using the D1 compound relation with the varga-sign lord). Other software may use slightly different point tables.
- Dasha browser: column per level (Maha → Prana); ▶ opens sub-periods, ◀ back, ▲▼ previous/next in the active column. Used for Vimshottari and Chara.
- Import/export: JSON file through the Android share sheet; import via file picker; clipboard backup kept.
- Colours live only in lib/brand.dart (astrowizard.co.in could not be fetched from the build sandbox; hex values must be supplied).

## Gulika / Mandi, XML, Dasha guide
- Gulika = ascendant at the START of Saturn's part, Mandi = ascendant at the MIDDLE of Saturn's part (Jagannatha Hora / Parashara's Light convention). Day = sunrise-sunset, night = sunset-next sunrise, 8 equal parts; day starts with the weekday lord, night with the 5th from it. Shown in D1 and all vargas as Gk / Md (not in Vimshottari, Shadbala, Ashtakavarga, Sudarshan).
- Checked against PyJHora for day births (within ~0.6-1.8 deg, difference = sunrise formula). PyJHora is wrong for births between midnight and sunrise and after sunset (it mixes dates), so those were checked by hand: e.g. Agra 05:27 birth -> Saturn's first night part of the previous evening, Gulika = ascendant at that sunset.
- XML: export is AstroWizard's own layout; import is tolerant (looks for name/date/time/timezone/latitude/longitude as tags or attributes). It has NOT been tested against a real Parashara's Light file.
- Dasha guide: houses are chosen manually (lord of / sitting in); content is in lib/engine/guide_data.dart.
