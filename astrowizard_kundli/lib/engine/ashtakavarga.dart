import 'constants.dart';

/// Benefic-point tables (BPHS): for each target planet, the houses counted
/// from every contributor (7 planets + Lagna) that receive a bindu.
const Map<String, Map<String, List<int>>> _av = {
  'Sun': {
    'Sun': [1, 2, 4, 7, 8, 9, 10, 11], 'Moon': [3, 6, 10, 11],
    'Mars': [1, 2, 4, 7, 8, 9, 10, 11], 'Mercury': [3, 5, 6, 9, 10, 11, 12],
    'Jupiter': [5, 6, 9, 11], 'Venus': [6, 7, 12],
    'Saturn': [1, 2, 4, 7, 8, 9, 10, 11], 'Lagna': [3, 4, 6, 10, 11, 12],
  },
  'Moon': {
    'Sun': [3, 6, 7, 8, 10, 11], 'Moon': [1, 3, 6, 7, 10, 11],
    'Mars': [2, 3, 5, 6, 9, 10, 11], 'Mercury': [1, 3, 4, 5, 7, 8, 10, 11],
    'Jupiter': [1, 4, 7, 8, 10, 11, 12], 'Venus': [3, 4, 5, 7, 9, 10, 11],
    'Saturn': [3, 5, 6, 11], 'Lagna': [3, 6, 10, 11],
  },
  'Mars': {
    'Sun': [3, 5, 6, 10, 11], 'Moon': [3, 6, 11],
    'Mars': [1, 2, 4, 7, 8, 10, 11], 'Mercury': [3, 5, 6, 11],
    'Jupiter': [6, 10, 11, 12], 'Venus': [6, 8, 11, 12],
    'Saturn': [1, 4, 7, 8, 9, 10, 11], 'Lagna': [1, 3, 6, 10, 11],
  },
  'Mercury': {
    'Sun': [5, 6, 9, 11, 12], 'Moon': [2, 4, 6, 8, 10, 11],
    'Mars': [1, 2, 4, 7, 8, 9, 10, 11], 'Mercury': [1, 3, 5, 6, 9, 10, 11, 12],
    'Jupiter': [6, 8, 11, 12], 'Venus': [1, 2, 3, 4, 5, 8, 9, 11],
    'Saturn': [1, 2, 4, 7, 8, 9, 10, 11], 'Lagna': [1, 2, 4, 6, 8, 10, 11],
  },
  'Jupiter': {
    'Sun': [1, 2, 3, 4, 7, 8, 9, 10, 11], 'Moon': [2, 5, 7, 9, 11],
    'Mars': [1, 2, 4, 7, 8, 10, 11], 'Mercury': [1, 2, 4, 5, 6, 9, 10, 11],
    'Jupiter': [1, 2, 3, 4, 7, 8, 10, 11], 'Venus': [2, 5, 6, 9, 10, 11],
    'Saturn': [3, 5, 6, 12], 'Lagna': [1, 2, 4, 5, 6, 7, 9, 10, 11],
  },
  'Venus': {
    'Sun': [8, 11, 12], 'Moon': [1, 2, 3, 4, 5, 8, 9, 11, 12],
    'Mars': [3, 5, 6, 9, 11, 12], 'Mercury': [3, 5, 6, 9, 11],
    'Jupiter': [5, 8, 9, 10, 11], 'Venus': [1, 2, 3, 4, 5, 8, 9, 10, 11],
    'Saturn': [3, 4, 5, 8, 9, 10, 11], 'Lagna': [1, 2, 3, 4, 5, 8, 9, 11],
  },
  'Saturn': {
    'Sun': [1, 2, 4, 7, 8, 10, 11], 'Moon': [3, 6, 11],
    'Mars': [3, 5, 6, 10, 11, 12], 'Mercury': [6, 8, 9, 10, 11, 12],
    'Jupiter': [5, 6, 11, 12], 'Venus': [6, 11, 12],
    'Saturn': [3, 5, 6, 11], 'Lagna': [1, 3, 4, 6, 10, 11],
  },
};

class Ashtakavarga {
  /// Bhinna Ashtakavarga: planet -> 12 bindu counts, indexed by sign (0 = Aries).
  final Map<String, List<int>> bav;

  /// Sarvashtakavarga: sum of the seven BAVs per sign (total is always 337).
  final List<int> sav;

  const Ashtakavarga(this.bav, this.sav);

  int total(String planet) => bav[planet]!.fold(0, (a, b) => a + b);
}

/// [rasiSigns] maps each of the seven planets to its D1 sign index.
Ashtakavarga computeAshtakavarga(Map<String, int> rasiSigns, int lagnaSign) {
  final pos = {...rasiSigns, 'Lagna': lagnaSign};
  final bav = <String, List<int>>{};
  _av.forEach((target, contributors) {
    final row = List<int>.filled(12, 0);
    contributors.forEach((who, houses) {
      for (final h in houses) {
        row[(pos[who]! + h - 1) % 12] += 1;
      }
    });
    bav[target] = row;
  });
  final sav = List<int>.generate(
      12, (i) => kSeven.fold(0, (sum, p) => sum + bav[p]![i]));
  return Ashtakavarga(bav, sav);
}
