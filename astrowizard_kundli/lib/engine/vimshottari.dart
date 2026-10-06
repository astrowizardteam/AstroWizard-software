const List<String> kDashaOrder = [
  'Ketu', 'Venus', 'Sun', 'Moon', 'Mars', 'Rahu', 'Jupiter', 'Saturn', 'Mercury',
];

const Map<String, int> kDashaYears = {
  'Ketu': 7, 'Venus': 20, 'Sun': 6, 'Moon': 10, 'Mars': 7,
  'Rahu': 18, 'Jupiter': 16, 'Saturn': 19, 'Mercury': 17,
};

/// Dasha year = 365.25 days, expressed in microseconds (exact integer).
const int _yearUs = 31557600 * 1000000;
const double _nakSpan = 360.0 / 27;

const List<String> kDashaLevelNames = [
  'Mahadasha', 'Antardasha', 'Pratyantardasha', 'Sookshma', 'Prana',
];

/// One Vimshottari period at any of the five levels
/// (1 = Maha, 2 = Antar, 3 = Pratyantar, 4 = Sookshma, 5 = Prana). Times are wall-clock values (UTC-flagged).
class DashaPeriod {
  final String lord;
  final DateTime start;
  final DateTime end;
  final int level;

  const DashaPeriod(this.lord, this.start, this.end, this.level);

  String get levelName => kDashaLevelNames[level - 1];

  /// The nine sub-periods of the next level (empty at Prana level).
  /// Generated on demand, so the whole 5-level tree is never built at once.
  List<DashaPeriod> get children {
    if (level >= 5) return const [];
    final total = end.difference(start).inMicroseconds;
    final first = kDashaOrder.indexOf(lord);
    final out = <DashaPeriod>[];
    var cum = 0;
    for (var i = 0; i < 9; i++) {
      final l = kDashaOrder[(first + i) % 9];
      final s = start.add(Duration(microseconds: (total * cum / 120).round()));
      cum += kDashaYears[l]!;
      final e = i == 8
          ? end
          : start.add(Duration(microseconds: (total * cum / 120).round()));
      out.add(DashaPeriod(l, s, e, level + 1));
    }
    return out;
  }
}

/// The nine Mahadashas from the Moon's sidereal longitude and the birth
/// wall-clock moment (down to the second).
List<DashaPeriod> buildVimshottari(double moonLongitude, DateTime birthWall) {
  final nakIndex = (moonLongitude ~/ _nakSpan) % 27;
  final firstLord = kDashaOrder[nakIndex % 9];
  final elapsed = (moonLongitude % _nakSpan) / _nakSpan;

  final start = birthWall.subtract(
      Duration(microseconds: (kDashaYears[firstLord]! * _yearUs * elapsed).round()));
  final firstIdx = kDashaOrder.indexOf(firstLord);

  final result = <DashaPeriod>[];
  var cum = 0;
  for (var i = 0; i < 9; i++) {
    final lord = kDashaOrder[(firstIdx + i) % 9];
    final s = start.add(Duration(microseconds: cum * _yearUs));
    cum += kDashaYears[lord]!;
    final e = start.add(Duration(microseconds: cum * _yearUs));
    result.add(DashaPeriod(lord, s, e, 1));
  }
  return result;
}

/// The chain of periods running at [when], from Mahadasha down to Prana
/// (up to [levels] entries).
List<DashaPeriod> runningDasha(List<DashaPeriod> mahas, DateTime when,
    {int levels = 5}) {
  final result = <DashaPeriod>[];
  var list = mahas;
  for (var lv = 0; lv < levels; lv++) {
    DashaPeriod? hit;
    for (final p in list) {
      if (!when.isBefore(p.start) && when.isBefore(p.end)) {
        hit = p;
        break;
      }
    }
    if (hit == null) break;
    result.add(hit);
    list = hit.children;
  }
  return result;
}
