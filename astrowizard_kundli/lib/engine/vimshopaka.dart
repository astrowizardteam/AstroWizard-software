import 'constants.dart';
import 'relations.dart';
import 'varga.dart';

/// Weights of the sixteen vargas in Vimshopaka (Shodasavarga) bala; they add
/// up to 20. Parashara's scheme as commonly tabulated.
const Map<int, double> kVimshopakaWeights = {
  1: 3.5, 2: 1, 3: 1, 4: 0.5, 7: 0.5, 9: 3, 10: 0.5, 12: 0.5,
  16: 2, 20: 0.5, 24: 0.5, 27: 0.5, 30: 1, 40: 0.5, 45: 0.5, 60: 4,
};

const Map<String, int> _exalt = {
  'Sun': 0, 'Moon': 1, 'Mars': 9, 'Mercury': 5, 'Jupiter': 3, 'Venus': 11, 'Saturn': 6,
};

/// Dignity points (out of 20) of a planet standing in [sign] of a varga:
/// own or exalted 20, adhi-mitra 18, mitra 15, sama 10, shatru 7, adhi-shatru 5.
double vargaDignityPoints(String planet, int sign, Relations rel) {
  final lord = kSignLords[sign];
  if (lord == planet || _exalt[planet] == sign) return 20;
  return switch (rel.of(planet, lord).compound) {
    2 => 18,
    1 => 15,
    0 => 10,
    -1 => 7,
    _ => 5,
  };
}

class Vimshopaka {
  /// planet -> division -> dignity points (0..20)
  final Map<String, Map<int, double>> points;
  /// planet -> weighted total (0..20)
  final Map<String, double> total;
  const Vimshopaka(this.points, this.total);

  static String grade(double v) => v >= 18
      ? 'Poorna'
      : v >= 15
          ? 'Atyuttama'
          : v >= 12
              ? 'Uttama'
              : v >= 10
                  ? 'Madhyama'
                  : 'Kanishtha';
}

/// Vimshopaka bala for the seven planets. The relations used are the D1
/// (natural + temporal) relations, as in the rest of the app.
Vimshopaka computeVimshopaka(Map<int, VargaChart> vargas, Relations rel) {
  final pts = <String, Map<int, double>>{};
  final tot = <String, double>{};
  for (final p in kSeven) {
    final m = <int, double>{};
    var sum = 0.0;
    for (final e in kVimshopakaWeights.entries) {
      final v = vargas[e.key];
      if (v == null) continue;
      final pt = vargaDignityPoints(p, v.signs[p]!, rel);
      m[e.key] = pt;
      sum += pt * e.value / 20;
    }
    pts[p] = m;
    tot[p] = sum;
  }
  return Vimshopaka(pts, tot);
}
