import 'constants.dart';

/// Natural friendship (naisargika maitri), BPHS. 1 friend, 0 neutral, -1 enemy.
const Map<String, Map<String, int>> kNaturalFriendship = {
  'Sun': {'Moon': 1, 'Mars': 1, 'Mercury': 0, 'Jupiter': 1, 'Venus': -1, 'Saturn': -1},
  'Moon': {'Sun': 1, 'Mars': 0, 'Mercury': 1, 'Jupiter': 0, 'Venus': 0, 'Saturn': 0},
  'Mars': {'Sun': 1, 'Moon': 1, 'Mercury': -1, 'Jupiter': 1, 'Venus': 0, 'Saturn': 0},
  'Mercury': {'Sun': 1, 'Moon': -1, 'Mars': 0, 'Jupiter': 0, 'Venus': 1, 'Saturn': 0},
  'Jupiter': {'Sun': 1, 'Moon': 1, 'Mars': 1, 'Mercury': -1, 'Venus': -1, 'Saturn': 0},
  'Venus': {'Sun': -1, 'Moon': -1, 'Mars': 0, 'Mercury': 1, 'Jupiter': 0, 'Saturn': 1},
  'Saturn': {'Sun': -1, 'Moon': -1, 'Mars': -1, 'Mercury': 1, 'Jupiter': 0, 'Venus': 1},
};

/// Temporal friendship (tatkalika maitri): a planet is a temporary friend of
/// another when it stands in the 2nd, 3rd, 4th, 10th, 11th or 12th sign from
/// it, and a temporary enemy otherwise (the 1st, 5th, 6th, 7th, 8th, 9th).
int temporalFriendship(int signOfA, int signOfB) {
  final house = (signOfB - signOfA) % 12 + 1; // house of B counted from A
  return const [2, 3, 4, 10, 11, 12].contains(house) ? 1 : -1;
}

/// Compound (panchadha) maitri = natural + temporal:
/// +2 adhi-mitra, +1 mitra, 0 sama, -1 shatru, -2 adhi-shatru.
String compoundName(int v) => switch (v) {
      2 => 'Adhi-mitra',
      1 => 'Mitra',
      0 => 'Sama',
      -1 => 'Shatru',
      _ => 'Adhi-shatru',
    };

class Relation {
  final int natural;
  final int temporal;
  const Relation(this.natural, this.temporal);
  int get compound => natural + temporal;
}

class Relations {
  /// key: "A>B" = how planet A regards planet B.
  final Map<String, Relation> table;
  const Relations(this.table);

  Relation of(String a, String b) => table['$a>$b']!;
}

/// [rasi]: planet -> sign index (0 = Aries) for the seven planets.
Relations computeRelations(Map<String, int> rasi) {
  final t = <String, Relation>{};
  for (final a in kSeven) {
    for (final b in kSeven) {
      if (a == b) continue;
      t['$a>$b'] =
          Relation(kNaturalFriendship[a]![b]!, temporalFriendship(rasi[a]!, rasi[b]!));
    }
  }
  return Relations(t);
}
