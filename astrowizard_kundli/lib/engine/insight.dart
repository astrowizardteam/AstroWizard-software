import 'ashtakavarga.dart';
import 'constants.dart';
import 'relations.dart';
import 'shadbala.dart';
import 'varga.dart';

const Map<String, int> _exaltSign = {
  'Sun': 0, 'Moon': 1, 'Mars': 9, 'Mercury': 5, 'Jupiter': 3, 'Venus': 11, 'Saturn': 6,
};
const Map<String, List<int>> _ownSigns = {
  'Sun': [4], 'Moon': [3], 'Mars': [0, 7], 'Mercury': [2, 5],
  'Jupiter': [8, 11], 'Venus': [1, 6], 'Saturn': [9, 10],
};
const Map<String, double> _combustDeg = {
  'Moon': 12, 'Mars': 17, 'Mercury': 14, 'Jupiter': 11, 'Venus': 10, 'Saturn': 15,
};
const Map<String, List<int>> _aspectOffsets = {
  'Mars': [4, 7, 8], 'Jupiter': [5, 7, 9], 'Saturn': [3, 7, 10],
  'Rahu': [5, 7, 9], 'Ketu': [5, 7, 9],
};
const List<String> _baladi = ['Bala', 'Kumara', 'Yuva', 'Vriddha', 'Mrita'];
const List<String> _karakas7 = [
  'Atmakaraka', 'Amatyakaraka', 'Bhratrikaraka', 'Matrikaraka',
  'Pitrikaraka', 'Putrakaraka', 'Darakaraka',
];
const List<String> _karakas8 = [
  'Atmakaraka', 'Amatyakaraka', 'Bhratrikaraka', 'Matrikaraka',
  'Pitrikaraka', 'Putrakaraka', 'Gnatikaraka', 'Darakaraka',
];
const List<String> _allNine = [...kSeven, 'Rahu', 'Ketu'];

/// Houses (counted from the planet's own house) that a planet aspects.
List<int> aspectOffsets(String planet) => _aspectOffsets[planet] ?? const [7];

/// A planet aspecting another house: [offset]th house from itself.
class AspectFrom {
  final int offset; // 7 = seventh from the planet
  final int house; // house number from lagna
  final List<String> planets; // planets standing in that house
  const AspectFrom(this.offset, this.house, this.planets);
}

class AspectTo {
  final String planet;
  final int offset;
  final double? virupa; // sphuta drishti strength, seven planets only
  const AspectTo(this.planet, this.offset, this.virupa);
}

class Dominance {
  final double shadbala, ashtakavarga, dignity, aspects;
  final int bindus;
  int rank;
  Dominance(this.shadbala, this.ashtakavarga, this.dignity, this.aspects,
      this.bindus, this.rank);
  double get total => shadbala + ashtakavarga + dignity + aspects;
}

class PlanetInsight {
  final String planet;
  final int house;
  final int sign;
  final bool retrograde;
  final List<String> conjunct;
  final List<AspectFrom> aspectsFrom;
  final List<AspectTo> aspectsTo;
  final String? karaka7; // Jaimini chara karaka, 7-planet scheme
  final String? karaka8; // 8-planet scheme (with Rahu)

  // Seven planets only (null for Rahu / Ketu)
  final List<int>? lordOf; // houses ruled
  final String? baladi, jagradadi, deeptadi, dignity;
  final bool? combust, vargottama;
  final Dominance? dominance;

  PlanetInsight({
    required this.planet,
    required this.house,
    required this.sign,
    required this.retrograde,
    required this.conjunct,
    required this.aspectsFrom,
    required this.aspectsTo,
    required this.karaka7,
    required this.karaka8,
    this.lordOf,
    this.baladi,
    this.jagradadi,
    this.deeptadi,
    this.dignity,
    this.combust,
    this.vargottama,
    this.dominance,
  });
}

(String, int) _dignity(String p, int sign, Relations rel) {
  if (_exaltSign[p] == sign) return ('Exalted', 20);
  if ((_exaltSign[p]! + 6) % 12 == sign) return ('Debilitated', 0);
  if (_ownSigns[p]!.contains(sign)) return ('Own sign', 17);
  final lord = kSignLords[sign];
  return switch (rel.of(p, lord).compound) {
    2 => ('Adhi-mitra sign', 15),
    1 => ("Friend's sign", 12),
    0 => ('Neutral sign', 8),
    -1 => ("Enemy's sign", 4),
    _ => ('Adhi-shatru sign', 2),
  };
}

Map<String, String> _charaKarakas(Map<String, double> lon, bool includeRahu) {
  final cand = <(double, String)>[
    for (final p in kSeven) (lon[p]! % 30, p),
    if (includeRahu) (30 - lon['Rahu']! % 30, 'Rahu'),
  ]..sort((a, b) => b.$1.compareTo(a.$1));
  final names = includeRahu ? _karakas8 : _karakas7;
  return {for (var i = 0; i < cand.length; i++) cand[i].$2: names[i]};
}

/// Details shown when a planet is tapped: aspects to / from, avasthas,
/// Jaimini chara karaka and an overall dominance index.
///
/// Dominance index (0-100, app-defined and transparent): Shadbala 40 +
/// Ashtakavarga bindus in its sign 20 + dignity 20 + net aspect (Drik bala) 20.
Map<String, PlanetInsight> computeInsight({
  required Map<String, double> lon, // all nine
  required Map<String, double> speed,
  required double asc,
  required ShadbalaResult shadbala,
  required Ashtakavarga ashtakavarga,
  required Relations relations,
}) {
  final lagna = asc ~/ 30;
  final sign = {for (final p in _allNine) p: lon[p]! ~/ 30};
  final house = {for (final p in _allNine) p: (sign[p]! - lagna) % 12 + 1};
  final k7 = _charaKarakas(lon, false);
  final k8 = _charaKarakas(lon, true);
  final out = <String, PlanetInsight>{};

  for (final p in _allNine) {
    final h = house[p]!;
    final from = <AspectFrom>[
      for (final off in aspectOffsets(p))
        () {
          final th = (h + off - 2) % 12 + 1;
          return AspectFrom(off, th, [
            for (final q in _allNine)
              if (q != p && house[q] == th) q,
          ]);
        }(),
    ];
    final to = <AspectTo>[];
    for (final q in _allNine) {
      if (q == p) continue;
      for (final off in aspectOffsets(q)) {
        if ((house[q]! + off - 2) % 12 + 1 == h) {
          final v = (kSeven.contains(q) && kSeven.contains(p))
              ? sphutaDrishti((lon[p]! - lon[q]!) % 360, q)
              : null;
          to.add(AspectTo(q, off, v));
        }
      }
    }
    final conj = [
      for (final q in _allNine)
        if (q != p && house[q] == h) q,
    ];

    if (!kSeven.contains(p)) {
      out[p] = PlanetInsight(
        planet: p,
        house: h,
        sign: sign[p]!,
        retrograde: (speed[p] ?? 0) < 0,
        conjunct: conj,
        aspectsFrom: from,
        aspectsTo: to,
        karaka7: k7[p],
        karaka8: k8[p],
      );
      continue;
    }

    final d = lon[p]! % 30;
    final idx = (d ~/ 6).clamp(0, 4);
    final baladi = _baladi[sign[p]! % 2 == 0 ? idx : 4 - idx];
    final (dname, dpts) = _dignity(p, sign[p]!, relations);
    final sep = (((lon[p]! - lon['Sun']! + 180) % 360) - 180).abs();
    var limit = _combustDeg[p];
    if (p == 'Mercury' && speed[p]! < 0) limit = 12;
    if (p == 'Venus' && speed[p]! < 0) limit = 8;
    final combust = limit != null && sep < limit;
    final jag = (dname == 'Exalted' || dname == 'Own sign')
        ? 'Jagrat'
        : (dname == 'Debilitated' || dname == "Enemy's sign" || dname == 'Adhi-shatru sign')
            ? 'Sushupti'
            : 'Swapna';
    final String deep;
    if (combust) {
      deep = 'Kopita';
    } else {
      deep = switch (dname) {
        'Exalted' => 'Deepta',
        'Own sign' => 'Swastha',
        'Debilitated' => 'Khala',
        'Adhi-mitra sign' => 'Mudita',
        "Friend's sign" => 'Shanta',
        'Neutral sign' => 'Dina',
        "Enemy's sign" => 'Dukhita',
        _ => 'Vikala',
      };
    }
    final s = shadbala.planets[p]!;
    final bindus = ashtakavarga.bav[p]![sign[p]!];
    final dom = Dominance(
      (s.ratio > 1.5 ? 1.5 : s.ratio) / 1.5 * 40,
      bindus / 8 * 20,
      dpts.toDouble(),
      20 * (((s.drik + 30) / 60).clamp(0.0, 1.0)),
      bindus,
      0,
    );
    out[p] = PlanetInsight(
      planet: p,
      house: h,
      sign: sign[p]!,
      retrograde: speed[p]! < 0,
      conjunct: conj,
      aspectsFrom: from,
      aspectsTo: to,
      karaka7: k7[p],
      karaka8: k8[p],
      lordOf: ([for (final sg in _ownSigns[p]!) (sg - lagna) % 12 + 1]..sort()),
      baladi: baladi,
      jagradadi: jag,
      deeptadi: deep,
      dignity: dname,
      combust: combust,
      vargottama: vargaSign(lon[p]!, 9) == sign[p],
      dominance: dom,
    );
  }
  final ranked = [...kSeven]
    ..sort((a, b) => out[b]!.dominance!.total.compareTo(out[a]!.dominance!.total));
  for (var i = 0; i < ranked.length; i++) {
    out[ranked[i]]!.dominance!.rank = i + 1;
  }
  return out;
}
