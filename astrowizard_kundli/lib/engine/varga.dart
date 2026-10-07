/// Divisional-chart sign (0 = Aries) of a sidereal longitude, per Parashara.
/// The sixteen Shodashavarga divisions: 1, 2, 3, 4, 7, 9, 10, 12, 16, 20, 24,
/// 27, 30, 40, 45, 60.
int vargaSign(double lon, int n) {
  final s = lon ~/ 30;
  final d = lon % 30;
  final odd = s % 2 == 0; // Aries, Gemini, ... are odd signs
  switch (n) {
    case 1:
      return s;
    case 2:
      return (odd == (d < 15)) ? 4 : 3; // Sun's hora = Leo, Moon's = Cancer
    case 3:
      return (s + 4 * (d ~/ 10)) % 12; // same sign, 5th, 9th
    case 4:
      return (s + 3 * (d / 7.5).floor()) % 12; // same sign, 4th, 7th, 10th
    case 7:
      {
        final part = (d * 7 / 30).floor();
        return ((odd ? s : (s + 6) % 12) + part) % 12;
      }
    case 9:
      return (lon * 3 / 10).floor() % 12;
    case 10:
      {
        final part = d ~/ 3;
        return ((odd ? s : (s + 8) % 12) + part) % 12;
      }
    case 12:
      return (s + (d / 2.5).floor()) % 12;
    case 16:
      return (_start(s, 0, 4, 8) + (d * 16 / 30).floor()) % 12;
    case 20:
      return (_start(s, 0, 8, 4) + (d / 1.5).floor()) % 12;
    case 24:
      return ((odd ? 4 : 3) + (d / 1.25).floor()) % 12; // odd: Leo, even: Cancer
    case 27:
      return ((const [0, 3, 6, 9])[s % 4] + (d * 27 / 30).floor()) % 12;
    case 40:
      return ((odd ? 0 : 6) + (d / 0.75).floor()) % 12; // odd: Aries, even: Libra
    case 45:
      return (_start(s, 0, 4, 8) + (d * 45 / 30).floor()) % 12;
    case 60:
      return (s + (d * 2).floor()) % 12;
    case 30:
      const oddTable = [(5.0, 0), (10.0, 10), (18.0, 8), (25.0, 2), (30.0, 6)];
      const evenTable = [(5.0, 1), (12.0, 5), (20.0, 11), (25.0, 9), (30.0, 7)];
      for (final (lim, sg) in (odd ? oddTable : evenTable)) {
        if (d < lim) return sg;
      }
      return odd ? 6 : 7;
  }
  throw ArgumentError('Unsupported varga D$n');
}

/// First sign of the cycle for movable / fixed / dual signs.
int _start(int s, int movable, int fixed, int dual) =>
    s % 3 == 0 ? movable : (s % 3 == 1 ? fixed : dual);

/// Degree (0..30) of a longitude inside its divisional sign: the part is
/// stretched to the full 30 degrees. D30 uses its unequal bands.
double vargaDegree(double lon, int n) {
  if (n == 30) {
    final d = lon % 30;
    final odd = (lon ~/ 30) % 2 == 0;
    const oddLim = [0.0, 5.0, 10.0, 18.0, 25.0, 30.0];
    const evenLim = [0.0, 5.0, 12.0, 20.0, 25.0, 30.0];
    final lim = odd ? oddLim : evenLim;
    for (var i = 1; i < lim.length; i++) {
      if (d < lim[i]) return (d - lim[i - 1]) / (lim[i] - lim[i - 1]) * 30;
    }
    return 30;
  }
  final size = 30.0 / n;
  return ((lon % 30) % size) * n;
}

/// A divisional chart: lagna sign plus the sign (and degree) of every planet.
class VargaChart {
  final int division; // 1, 3, 9, 10 ...
  final int lagnaSign;
  final Map<String, int> signs; // planet -> sign index
  final double lagnaDegree; // degree of the lagna inside its varga sign
  final Map<String, double> degrees; // planet -> degree inside its varga sign

  const VargaChart(this.division, this.lagnaSign, this.signs,
      {this.lagnaDegree = 0, this.degrees = const {}});

  String get title => kVargaNames[division] ?? 'D$division';

  /// House (1..12, whole-sign) of a planet in this chart.
  int houseOf(String planet) => (signs[planet]! - lagnaSign) % 12 + 1;
}

/// The sixteen divisions of the Shodashavarga scheme.
const List<int> kShownVargas = [1, 2, 3, 4, 7, 9, 10, 12, 16, 20, 24, 27, 30, 40, 45, 60];

const Map<int, String> kVargaNames = {
  1: 'D1 Rasi',
  2: 'D2 Hora',
  3: 'D3 Drekkana',
  4: 'D4 Chaturthamsa',
  7: 'D7 Saptamsa',
  9: 'D9 Navamsa',
  10: 'D10 Dasamsa',
  12: 'D12 Dwadasamsa',
  16: 'D16 Shodasamsa',
  20: 'D20 Vimsamsa',
  24: 'D24 Siddhamsa',
  27: 'D27 Bhamsa',
  30: 'D30 Trimsamsa',
  40: 'D40 Khavedamsa',
  45: 'D45 Akshavedamsa',
  60: 'D60 Shashtiamsa',
};

VargaChart buildVarga(int n, double ascendant, Map<String, double> lons) {
  return VargaChart(
    n,
    vargaSign(ascendant, n),
    {for (final e in lons.entries) e.key: vargaSign(e.value, n)},
    lagnaDegree: vargaDegree(ascendant, n),
    degrees: {for (final e in lons.entries) e.key: vargaDegree(e.value, n)},
  );
}
