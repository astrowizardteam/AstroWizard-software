import 'constants.dart';

/// Jaimini Chara dasha (K.N. Rao method), counted from the lagna sign.
/// Sign-based; five levels (Maha, Antar, Pratyantar, Sookshma, Prana).

const List<int> _oddFooted = [0, 1, 2, 6, 7, 8];
const List<int> _evenFooted = [3, 4, 5, 9, 10, 11];

/// Sign in which each planet is exalted (Rahu: Taurus, Ketu: Scorpio).
const Map<String, int> _exalt = {
  'Sun': 0, 'Moon': 1, 'Mars': 9, 'Mercury': 5, 'Jupiter': 3,
  'Venus': 11, 'Saturn': 6, 'Rahu': 1, 'Ketu': 7,
};

const int _yearUs = 31557600 * 1000000;

const List<String> kCharaLevelNames = [
  'Maha', 'Antar', 'Pratyantar', 'Sookshma', 'Prana',
];

class CharaPeriod {
  final int sign; // 0 = Aries
  final DateTime start;
  final DateTime end;
  final int level; // 1..5
  final bool forward;

  const CharaPeriod(this.sign, this.start, this.end, this.level, this.forward);

  String get name => kSigns[sign];
  String get levelName => kCharaLevelNames[level - 1];

  /// Twelve equal sub-periods, starting from this sign and moving in the
  /// same direction as the Mahadasha sequence. Built on demand.
  List<CharaPeriod> get children {
    if (level >= 5) return const [];
    final total = end.difference(start).inMicroseconds;
    final out = <CharaPeriod>[];
    for (var i = 0; i < 12; i++) {
      final sg = _step(sign, i, forward);
      final s = start.add(Duration(microseconds: (total * i / 12).round()));
      final e = i == 11
          ? end
          : start.add(Duration(microseconds: (total * (i + 1) / 12).round()));
      out.add(CharaPeriod(sg, s, e, level + 1, forward));
    }
    return out;
  }
}

int _step(int first, int i, bool forward) =>
    ((first + (forward ? i : -i)) % 12 + 12) % 12;

List<int> _rasiAspects(int s) {
  if (s % 3 == 0) return [for (final t in [1, 4, 7, 10]) if (t != (s + 1) % 12) t];
  if (s % 3 == 1) return [for (final t in [0, 3, 6, 9]) if (t != (s + 11) % 12) t];
  return [for (final t in [2, 5, 8, 11]) if (t != s) t];
}

const List<String> _nine = [
  'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn', 'Rahu', 'Ketu',
];

/// Stronger of the two co-lords of Scorpio (Mars/Ketu) or Aquarius (Saturn/Rahu).
String _strongerCoLord(String a, String b, Map<String, double> lon) {
  final home = (a == 'Mars') ? 7 : 10;
  int sg(String p) => lon[p]! ~/ 30 % 12;
  final sa = sg(a), sb = sg(b);
  if (sa == home && sb != home) return b;
  if (sb == home && sa != home) return a;
  final ca = _nine.where((q) => q != a && sg(q) == sa).length;
  final cb = _nine.where((q) => q != b && sg(q) == sb).length;
  if (ca != cb) return ca > cb ? a : b;

  int support(int s) {
    var n = 0;
    for (final q in ['Jupiter', 'Mercury', kSignLords[s]]) {
      final sq = sg(q);
      if (sq == s || _rasiAspects(sq).contains(s)) n++;
    }
    return n;
  }

  final ra = support(sa), rb = support(sb);
  if (ra != rb) return ra > rb ? a : b;
  final ea = _exalt[a] == sa, eb = _exalt[b] == sb;
  if (ea != eb) return ea ? a : b;
  int rank(int s) => s % 3 == 2 ? 3 : (s % 3 == 1 ? 2 : 1);
  if (rank(sa) != rank(sb)) return rank(sa) > rank(sb) ? a : b;
  return (lon[a]! % 30) > (lon[b]! % 30) ? a : b;
}

String charaLord(int sign, Map<String, double> lon) {
  if (sign == 7) return _strongerCoLord('Mars', 'Ketu', lon);
  if (sign == 10) return _strongerCoLord('Saturn', 'Rahu', lon);
  return kSignLords[sign];
}

/// Years of a sign's Mahadasha (first cycle).
int charaYears(int sign, Map<String, double> lon) {
  final lord = charaLord(sign, lon);
  final ls = lon[lord]! ~/ 30 % 12;
  final n = _evenFooted.contains(sign) ? ((sign - ls) % 12 + 12) % 12 : ((ls - sign) % 12 + 12) % 12;
  var years = n > 0 ? n : 12;
  if (_exalt[lord] == ls) {
    years += 1;
  } else if ((_exalt[lord]! + 6) % 12 == ls) {
    years -= 1;
  }
  return years;
}

/// Sequence runs zodiacally when the 9th sign from the lagna is odd-footed.
bool charaForward(int lagna) => _oddFooted.contains((lagna + 8) % 12);

/// Two cycles (144 years): the second cycle uses 12 − years; zero-year signs are skipped.
List<CharaPeriod> buildCharaDasha(
    Map<String, double> lon, double ascendant, DateTime birthWall) {
  final lagna = ascendant ~/ 30 % 12;
  final fwd = charaForward(lagna);
  final out = <CharaPeriod>[];
  var t = birthWall;
  for (var cycle = 0; cycle < 2; cycle++) {
    for (var i = 0; i < 12; i++) {
      final sg = _step(lagna, i, fwd);
      var y = charaYears(sg, lon);
      if (cycle == 1) y = 12 - y;
      if (y <= 0) continue;
      final e = t.add(Duration(microseconds: y * _yearUs));
      out.add(CharaPeriod(sg, t, e, 1, fwd));
      t = e;
    }
  }
  return out;
}

List<CharaPeriod> runningChara(List<CharaPeriod> mahas, DateTime when,
    {int levels = 5}) {
  final res = <CharaPeriod>[];
  var list = mahas;
  for (var lv = 0; lv < levels; lv++) {
    CharaPeriod? hit;
    for (final p in list) {
      if (!when.isBefore(p.start) && when.isBefore(p.end)) {
        hit = p;
        break;
      }
    }
    if (hit == null) break;
    res.add(hit);
    list = hit.children;
  }
  return res;
}
