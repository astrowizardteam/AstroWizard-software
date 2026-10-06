/// Divisional-chart sign (0 = Aries) of a sidereal longitude, per Parashara.
/// Supported: 1, 2, 3, 7, 9, 10, 12, 30.
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

/// Degree (0..30) of a longitude inside its divisional sign, for the equal-part
/// vargas (D1, D3, D9, D10, D12): the part is stretched to the full 30 degrees.
double vargaDegree(double lon, int n) {
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

  String get title => switch (division) {
        1 => 'D1 Rasi',
        3 => 'D3 Drekkana',
        9 => 'D9 Navamsa',
        10 => 'D10 Dasamsa',
        _ => 'D$division',
      };

  /// House (1..12, whole-sign) of a planet in this chart.
  int houseOf(String planet) => (signs[planet]! - lagnaSign) % 12 + 1;
}

const List<int> kShownVargas = [1, 3, 9, 10];

VargaChart buildVarga(int n, double ascendant, Map<String, double> lons) {
  return VargaChart(
    n,
    vargaSign(ascendant, n),
    {for (final e in lons.entries) e.key: vargaSign(e.value, n)},
    lagnaDegree: vargaDegree(ascendant, n),
    degrees: {for (final e in lons.entries) e.key: vargaDegree(e.value, n)},
  );
}
