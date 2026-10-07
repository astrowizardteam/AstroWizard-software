import 'dart:io';

import 'package:sweph/sweph.dart';

import 'gulika.dart';
import 'models.dart';

/// All Swiss Ephemeris calls live in this one file, so the rest of the app
/// stays independent of the plugin. Uses the Swiss Ephemeris data files
/// (sepl_18 / semo_18, 1800-2400 AD, bundled as assets; sub-arc-second
/// accuracy) with the Lahiri ayanamsa. Outside that range Swiss Ephemeris
/// falls back to its built-in Moshier ephemeris automatically.
///
/// Why not Moshier only: its Moon error (up to ~3") shifts the Vimshottari
/// dasha start by many hours, which matters for the finest dasha levels.
///
/// NOTE: Swiss Ephemeris is dual-licensed (AGPL / commercial). Before a
/// closed-source Play Store release, buy the Swiss Ephemeris Professional
/// License from Astrodienst, or the app must be open-sourced under AGPL.
class EphemerisEngine {
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    // The default folder ('ephe_files') is relative and read-only on Android,
    // so the ephemeris files are unpacked into the app's own temp directory.
    await Sweph.init(
      epheAssets: const [
        'assets/ephe/sepl_18.se1',
        'assets/ephe/semo_18.se1',
      ],
      epheFilesPath: '${Directory.systemTemp.path}/ephe_files',
    );
    Sweph.swe_set_sid_mode(SiderealMode.SE_SIDM_LAHIRI);
    _ready = true;
  }

  static final SwephFlag _flags = SwephFlag.SEFLG_SWIEPH |
      SwephFlag.SEFLG_SIDEREAL |
      SwephFlag.SEFLG_SPEED;

  static const Map<String, HeavenlyBody> _bodies = {
    'Sun': HeavenlyBody.SE_SUN,
    'Moon': HeavenlyBody.SE_MOON,
    'Mars': HeavenlyBody.SE_MARS,
    'Mercury': HeavenlyBody.SE_MERCURY,
    'Jupiter': HeavenlyBody.SE_JUPITER,
    'Venus': HeavenlyBody.SE_VENUS,
    'Saturn': HeavenlyBody.SE_SATURN,
    'Rahu': HeavenlyBody.SE_MEAN_NODE,
  };

  static KundliChart compute(BirthData birth) {
    final ut = birth.utc;
    final jd = Sweph.swe_julday(
      ut.year,
      ut.month,
      ut.day,
      ut.hour + ut.minute / 60.0 + ut.second / 3600.0,
      CalendarType.SE_GREG_CAL,
    );

    // Ascendant / midheaven (sidereal). House system does not affect them.
    final houses = Sweph.swe_houses_ex(
      jd,
      SwephFlag.SEFLG_SIDEREAL,
      birth.latitude,
      birth.longitude,
      Hsys.E,
    );
    final asc = _norm(houses.ascmc[0]);
    final mc = _norm(houses.ascmc[1]);
    final lagnaSign = asc ~/ 30;

    final raw = <String, List<double>>{}; // name -> [lon, speed]
    _bodies.forEach((name, body) {
      final c = Sweph.swe_calc_ut(jd, body, _flags);
      raw[name] = [_norm(c.longitude), c.speedInLongitude];
    });
    raw['Ketu'] = [_norm(raw['Rahu']![0] + 180.0), raw['Rahu']![1]];

    final planets = <String, PlanetPosition>{};
    raw.forEach((name, v) {
      final sign = v[0] ~/ 30;
      planets[name] = PlanetPosition(
        name: name,
        longitude: v[0],
        speed: v[1],
        house: ((sign - lagnaSign) % 12) + 1, // whole-sign houses
      );
    });

    // Gulika & Mandi: ascendant at the start / middle of Saturn's part of the day.
    final up = upagrahaOffsets(birth.wall, birth.latitude, birth.longitude, birth.tzHours);
    if (up != null) {
      for (final e in {'Gulika': up.gulika, 'Mandi': up.mandi}.entries) {
        final h = Sweph.swe_houses_ex(jd + e.value / 24, SwephFlag.SEFLG_SIDEREAL,
            birth.latitude, birth.longitude, Hsys.E);
        final l = _norm(h.ascmc[0]);
        planets[e.key] = PlanetPosition(
          name: e.key,
          longitude: l,
          speed: 0,
          house: (((l ~/ 30) - lagnaSign) % 12) + 1,
        );
      }
    }

    final lons = {for (final e in planets.entries) e.key: e.value.longitude};
    final vargas = {
      for (final n in kShownVargas) n: buildVarga(n, asc, lons),
    };

    final rasi = {for (final p in kSeven) p: planets[p]!.signIndex};
    final ayan = Sweph.swe_get_ayanamsa_ut(jd);

    final av = computeAshtakavarga(rasi, lagnaSign);
    final rel = computeRelations(rasi);
    final sunLon = lons['Sun']!;
    final shadbala = computeShadbala(ShadbalaInput(
      lon: {for (final p in kSeven) p: lons[p]!},
      nodes: {'Rahu': lons['Rahu']!, 'Ketu': lons['Ketu']!},
      asc: asc,
      mc: mc,
      ayanamsa: ayan,
      jd: jd,
      tz: birth.tzHours,
      lat: birth.latitude,
      lonGeo: birth.longitude,
      wall: birth.wall,
    ));

    return KundliChart(
      birth: birth,
      julianDayUt: jd,
      ayanamsa: ayan,
      ascendant: asc,
      midheaven: mc,
      planets: planets,
      vargas: vargas,
      vimshottari: buildVimshottari(lons['Moon']!, birth.wall),
      chara: buildCharaDasha(lons, asc, birth.wall),
      panchang: computePanchang(
        sunLon,
        lons['Moon']!,
        birth.wall,
        birth.latitude,
        birth.longitude,
        birth.tzHours,
      ),
      ashtakavarga: av,
      shadbala: shadbala,
      relations: rel,
      insight: computeInsight(
        lon: lons,
        speed: {for (final e in planets.entries) e.key: e.value.speed},
        asc: asc,
        shadbala: shadbala,
        ashtakavarga: av,
        relations: rel,
      ),
      bhavaBala: computeBhavaBala(
        lon: {for (final p in kSeven) p: lons[p]!},
        asc: asc,
        mc: mc,
        shadbala: shadbala,
      ),
    );
  }

  /// Sidereal longitudes (and retrograde flags) of all nine grahas at the
  /// given real UTC instant, for transit (gochara) displays.
  static Map<String, PlanetPosition> transit(DateTime utc, int lagnaSign) {
    final jd = Sweph.swe_julday(utc.year, utc.month, utc.day,
        utc.hour + utc.minute / 60.0 + utc.second / 3600.0, CalendarType.SE_GREG_CAL);
    final out = <String, PlanetPosition>{};
    _bodies.forEach((name, body) {
      final c = Sweph.swe_calc_ut(jd, body, _flags);
      final lon = _norm(c.longitude);
      out[name] = PlanetPosition(
          name: name,
          longitude: lon,
          speed: c.speedInLongitude,
          house: ((lon ~/ 30 - lagnaSign) % 12) + 1);
    });
    final r = out['Rahu']!;
    final kl = _norm(r.longitude + 180.0);
    out['Ketu'] = PlanetPosition(
        name: 'Ketu',
        longitude: kl,
        speed: r.speed,
        house: ((kl ~/ 30 - lagnaSign) % 12) + 1);
    return out;
  }

  static double _norm(double d) {
    var r = d % 360.0;
    if (r < 0) r += 360.0;
    if (r >= 360.0) r -= 360.0; // tiny negatives can round up to exactly 360
    return r;
  }
}
