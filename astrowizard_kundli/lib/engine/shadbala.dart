import 'dart:math' as math;

import 'constants.dart';
import 'panchang.dart';
import 'relations.dart';
import 'varga.dart';

/// Shadbala (six-fold strength) of the seven planets, in virupas (60 = 1 rupa),
/// following the classical BPHS method.
///
/// Method follows B.V. Raman / V.P. Jain (validated against the worked
/// examples in both books; see tools/reference_engine.py and test/):
///  * Moolatrikona is sign-level (45 virupas anywhere in the sign).
///  * Abda / Masa lords use the classical ahargana count (360-day year, 30-day month).
///  * Ayana bala uses the declination of the sayana longitude (latitude ignored);
///    Mercury, Moon and Saturn use (23.45 - decl), the others (23.45 + decl).
///  * Sun and Moon get no Cheshta bala (as in the books).
///  * Drik bala adds the special-aspect increments of Mars / Jupiter / Saturn;
///    Mercury is benefic when alone or with more benefics, malefic otherwise;
///    the Moon is benefic while waxing.
/// Not included: Yuddha bala (planetary war); Cheshta bala uses modern mean
/// heliocentric longitudes (differs from Surya-Siddhanta tables by up to ~4 virupas).

const Map<String, double> _debil = {
  'Sun': 190.0, 'Moon': 213.0, 'Mars': 118.0, 'Mercury': 345.0,
  'Jupiter': 275.0, 'Venus': 177.0, 'Saturn': 20.0,
};

/// planet -> moolatrikona sign (sign-level, as in the classical books)
const Map<String, int> _moola = {
  'Sun': 4, 'Moon': 1, 'Mars': 0, 'Mercury': 5,
  'Jupiter': 8, 'Venus': 6, 'Saturn': 10,
};

const Map<String, double> _naisargika = {
  'Sun': 60.0, 'Moon': 51.43, 'Venus': 42.85, 'Jupiter': 34.28,
  'Mercury': 25.71, 'Mars': 17.14, 'Saturn': 8.57,
};

const Map<String, double> kShadbalaRequired = {
  'Sun': 390, 'Moon': 360, 'Mars': 300, 'Mercury': 420,
  'Jupiter': 390, 'Venus': 330, 'Saturn': 300,
};

// Mean heliocentric longitude at J2000 and rate per Julian century (degrees).
const Map<String, (double, double)> _meanL = {
  'Mercury': (252.25084, 149472.67411175),
  'Venus': (181.97973, 58517.81538729),
  'Earth': (100.46435, 35999.37244981),
  'Mars': (-4.55343205, 19140.30268499),
  'Jupiter': (34.39644051, 3034.74612775),
  'Saturn': (49.95424423, 1222.49362201),
};

double _wrap180(double x) => ((x + 180) % 360) - 180;
double _angDiff(double a, double b) => _wrap180(a - b).abs();

class ShadbalaInput {
  final Map<String, double> lon; // sidereal, 7 planets
  final Map<String, double> nodes; // Rahu / Ketu sidereal longitudes
  final double asc; // sidereal ascendant
  final double mc; // sidereal midheaven
  final double ayanamsa;
  final double jd; // UT Julian day of birth
  final double tz;
  final double lat;
  final double lonGeo;
  final DateTime wall; // UTC-flagged local wall-clock birth time

  const ShadbalaInput({
    required this.lon,
    required this.nodes,
    required this.asc,
    required this.mc,
    required this.ayanamsa,
    required this.jd,
    required this.tz,
    required this.lat,
    required this.lonGeo,
    required this.wall,
  });
}

class PlanetShadbala {
  final double uccha, saptavargaja, ojhayugma, kendradi, drekkana;
  final double sthana, dig, kala;
  final double nathonnata, paksha, tribhaga, abda, masa, vara, hora, ayana;
  final double cheshta, naisargika, drik;
  final double total;
  final double required;

  const PlanetShadbala({
    required this.uccha,
    required this.saptavargaja,
    required this.ojhayugma,
    required this.kendradi,
    required this.drekkana,
    required this.sthana,
    required this.dig,
    required this.kala,
    required this.nathonnata,
    required this.paksha,
    required this.tribhaga,
    required this.abda,
    required this.masa,
    required this.vara,
    required this.hora,
    required this.ayana,
    required this.cheshta,
    required this.naisargika,
    required this.drik,
    required this.total,
    required this.required,
  });

  double get rupas => total / 60;
  double get ratio => total / required;
  bool get strong => total >= required;
}

class ShadbalaResult {
  final Map<String, PlanetShadbala> planets;
  final String abdaLord, masaLord, horaLord, tribhagaLord, varaLord;

  /// Benefic (true) / malefic (false) status used for Drik bala, incl. the
  /// dynamic status of Mercury and the Moon.
  final Map<String, bool> benefic;

  const ShadbalaResult(this.planets, this.abdaLord, this.masaLord, this.horaLord,
      this.tribhagaLord, this.varaLord, this.benefic);
}

double _varaPoints(String planet, int vsign, Map<String, int> d1,
    {double? lonInD1}) {
  if (lonInD1 != null && (lonInD1 ~/ 30) == _moola[planet]!) return 45.0;
  final lord = kSignLords[vsign];
  if (lord == planet) return 30.0;
  final nat = kNaturalFriendship[planet]![lord]!;
  final house = (d1[lord]! - d1[planet]!) % 12 + 1;
  final temp = const [2, 3, 4, 10, 11, 12].contains(house) ? 1 : -1;
  switch (nat + temp) {
    case 2:
      return 22.5;
    case 1:
      return 15.0;
    case 0:
      return 7.5;
    case -1:
      return 3.75;
    default:
      return 1.875;
  }
}

/// Sphuta drishti (virupas) of [planet] on a point [d0] degrees ahead of it
/// (BV Raman table; Mars, Jupiter and Saturn special aspects are added).
double sphutaDrishti(double d0, String planet) {
  final d = d0 % 360;
  if (d < 30 || d >= 300) return 0.0;
  if (d < 60) return (d - 30) / 2;
  if (d < 90) return (d - 45) + (planet == 'Saturn' ? 45.0 : 0.0);
  if (d < 120) return 30 + (120 - d) / 2 + (planet == 'Mars' ? 15.0 : 0.0);
  if (d < 150) return (150 - d) + (planet == 'Jupiter' ? 30.0 : 0.0);
  if (d < 180) return (d - 150) * 2;
  var v = (300 - d) / 2;
  if (planet == 'Mars' && d >= 210 && d < 240) v += 15;
  if (planet == 'Jupiter' && d >= 240 && d < 270) v += 30;
  if (planet == 'Saturn' && d >= 270 && d < 300) v += 45;
  return v;
}

const List<String> _weekLords = [
  'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn',
];

int _jdn(int y, int m, int d) {
  final a = (14 - m) ~/ 12;
  final y2 = y + 4800 - a;
  final m2 = m + 12 * a - 3;
  return d + (153 * m2 + 2) ~/ 5 + 365 * y2 + y2 ~/ 4 - y2 ~/ 100 + y2 ~/ 400 - 32045;
}

ShadbalaResult computeShadbala(ShadbalaInput inp) {
  final lon = inp.lon;
  final asc = inp.asc;
  final mc = inp.mc;
  final wall = inp.wall;
  final tz = inp.tz;
  final lagna = asc ~/ 30;
  final d1 = {for (final p in kSeven) p: lon[p]! ~/ 30};

  // ---- shared timing data
  final hours = wall.hour + wall.minute / 60 + wall.second / 3600;
  final st = sunTimes(wall.year, wall.month, wall.day, inp.lat, inp.lonGeo, tz)!;
  final sr = st.rise;
  final ss = st.set;
  final vara = vedicVara(wall, inp.lat, inp.lonGeo, tz);
  final varaLord = kVaraLord[vara];
  final elong = (lon['Moon']! - lon['Sun']!) % 360;
  final elong180 = elong <= 180 ? elong : 360 - elong;
  final noon = (sr + ss) / 2;
  var dm = (hours - noon).abs();
  if (dm > 12) dm = 24 - dm;

  String triLord;
  if (hours >= sr && hours < ss) {
    final part = ((hours - sr) / ((ss - sr) / 3)).floor();
    triLord = const ['Mercury', 'Sun', 'Saturn'][math.min(part, 2)];
  } else {
    final double start, end;
    if (hours >= ss) {
      start = ss;
      end = sr + 24;
    } else {
      start = ss - 24;
      end = sr;
    }
    final part = ((hours - start) / ((end - start) / 3)).floor();
    triLord = const ['Moon', 'Venus', 'Mars'][math.min(part, 2)];
  }

  final hh = hours >= sr ? hours : hours + 24;
  final n = (hh - sr).floor();
  final horaLord = kChaldean[(kChaldean.indexOf(varaLord) + n) % 7];

  // Abda / Masa lords: classical ahargana (Kali epoch day = 1) on the Vedic day.
  final vday = hours >= sr ? wall : wall.subtract(const Duration(days: 1));
  final ahar = _jdn(vday.year, vday.month, vday.day) - 588465;
  final abdaLord = _weekLords[(360 * (ahar ~/ 360) + 4) % 7];
  final masaLord = _weekLords[(30 * (ahar ~/ 30) + 4) % 7];

  final tCent = (inp.jd - 2451545.0) / 36525.0;
  final sunMean =
      (_meanL['Earth']!.$1 + _meanL['Earth']!.$2 * tCent + 180) % 360;
  double hel(String p) => (_meanL[p]!.$1 + _meanL[p]!.$2 * tCent) % 360;

  final benefic = <String, bool>{
    'Jupiter': true, 'Venus': true, 'Moon': elong < 180,
    'Sun': false, 'Mars': false, 'Saturn': false,
  };
  // Mercury: benefic when alone or with more benefics; malefic with more
  // malefics; on a tie the nearest companion decides.
  double lonOf(String q) => inp.nodes[q] ?? lon[q]!;
  final comp = <String>[
    for (final q in [...kSeven, 'Rahu', 'Ketu'])
      if (q != 'Mercury' && lonOf(q) ~/ 30 == lon['Mercury']! ~/ 30) q,
  ];
  final nBen = comp.where((q) => benefic[q] ?? false).length;
  final nMal = comp.length - nBen;
  if (comp.isEmpty || nBen > nMal) {
    benefic['Mercury'] = true;
  } else if (nMal > nBen) {
    benefic['Mercury'] = false;
  } else {
    comp.sort((a, b) => (lonOf(a) - lon['Mercury']!).abs()
        .compareTo((lonOf(b) - lon['Mercury']!).abs()));
    benefic['Mercury'] = benefic[comp.first] ?? false;
  }

  final out = <String, PlanetShadbala>{};
  for (final p in kSeven) {
    final l = lon[p]!;
    // ---- Sthana bala
    final uc = _angDiff(l, _debil[p]!) / 3;
    var sv = 0.0;
    for (final v in const [1, 2, 3, 7, 9, 12, 30]) {
      sv += _varaPoints(p, vargaSign(l, v), d1, lonInD1: v == 1 ? l : null);
    }
    final rs = d1[p]!;
    final ns = vargaSign(l, 9);
    final wantEven = p == 'Moon' || p == 'Venus';
    var oj = 0.0;
    for (final sg in [rs, ns]) {
      if ((sg % 2 == 1) == wantEven) oj += 15.0;
    }
    final house = (d1[p]! - lagna) % 12 + 1;
    final ke = const [1, 4, 7, 10].contains(house)
        ? 60.0
        : (const [2, 5, 8, 11].contains(house) ? 30.0 : 15.0);
    final dg = l % 30;
    var dr = 0.0;
    if ((const ['Sun', 'Jupiter', 'Mars'].contains(p) && dg < 10) ||
        (const ['Mercury', 'Saturn'].contains(p) && dg >= 10 && dg < 20) ||
        (const ['Moon', 'Venus'].contains(p) && dg >= 20)) {
      dr = 15.0;
    }
    final sthana = uc + sv + oj + ke + dr;

    // ---- Dig bala
    final strong = const {
      'Jupiter': 0, 'Mercury': 0, 'Sun': 1, 'Mars': 1,
      'Saturn': 2, 'Moon': 3, 'Venus': 3,
    }[p]!;
    final strongPoint = switch (strong) {
      0 => asc,
      1 => mc,
      2 => (asc + 180) % 360,
      _ => (mc + 180) % 360,
    };
    final dig = _angDiff(l, (strongPoint + 180) % 360) / 3;

    // ---- Kala bala
    final double nato;
    if (p == 'Mercury') {
      nato = 60.0;
    } else if (p == 'Moon' || p == 'Mars' || p == 'Saturn') {
      nato = dm / 12 * 60;
    } else {
      nato = 60 - dm / 12 * 60;
    }
    final pakPlain = benefic[p]! ? elong180 / 3 : 60 - elong180 / 3;
    final pak = p == 'Moon' ? pakPlain * 2 : pakPlain;
    final tri = (p == 'Jupiter' || p == triLord) ? 60.0 : 0.0;
    final abda = p == abdaLord ? 15.0 : 0.0;
    final masa = p == masaLord ? 30.0 : 0.0;
    final vr = p == varaLord ? 45.0 : 0.0;
    final hr = p == horaLord ? 60.0 : 0.0;
    // declination from the sayana longitude only (latitude ignored), as in the books
    final d = math.asin(math.sin(23.45 * math.pi / 180) *
            math.sin(((l + inp.ayanamsa) % 360) * math.pi / 180)) *
        180 / math.pi;
    var ayPlain = (p == 'Moon' || p == 'Saturn' || p == 'Mercury')
        ? (23.45 - d) / 46.9 * 60
        : (23.45 + d) / 46.9 * 60;
    ayPlain = math.max(0.0, math.min(60.0, ayPlain));
    final ay = p == 'Sun' ? ayPlain * 2 : ayPlain;
    final kala = nato + pak + tri + abda + masa + vr + hr + ay;

    // ---- Cheshta bala
    final double ch;
    if (p == 'Sun' || p == 'Moon') {
      ch = 0.0; // books give Sun / Moon no Cheshta bala
    } else {
      final sph = (l + inp.ayanamsa) % 360;
      final double seeghra, madhya;
      if (p == 'Mars' || p == 'Jupiter' || p == 'Saturn') {
        seeghra = sunMean;
        madhya = hel(p);
      } else {
        seeghra = hel(p);
        madhya = sunMean;
      }
      final avg = madhya + _wrap180(sph - madhya) / 2;
      ch = _angDiff(seeghra, avg) / 3;
    }

    // ---- Drik bala
    var acc = 0.0;
    for (final q in kSeven) {
      if (q == p) continue;
      final dd = (l - lon[q]!) % 360;
      final v = sphutaDrishti(dd, q);
      acc += benefic[q]! ? v : -v;
    }
    final drik = acc / 4;

    final total = sthana + dig + kala + ch + _naisargika[p]! + drik;
    out[p] = PlanetShadbala(
      uccha: uc,
      saptavargaja: sv,
      ojhayugma: oj,
      kendradi: ke,
      drekkana: dr,
      sthana: sthana,
      dig: dig,
      kala: kala,
      nathonnata: nato,
      paksha: pak,
      tribhaga: tri,
      abda: abda,
      masa: masa,
      vara: vr,
      hora: hr,
      ayana: ay,
      cheshta: ch,
      naisargika: _naisargika[p]!,
      drik: drik,
      total: total,
      required: kShadbalaRequired[p]!,
    );
  }
  return ShadbalaResult(out, abdaLord, masaLord, horaLord, triLord, varaLord, benefic);
}
