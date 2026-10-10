import 'dart:convert';
import 'dart:io';

import 'package:astrowizard_kundli/engine/models.dart';
import 'package:astrowizard_kundli/access.dart';
import 'package:astrowizard_kundli/engine/gulika.dart';
import 'package:astrowizard_kundli/engine/vimshopaka.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden values come from tools/reference_engine.py (Swiss Ephemeris).
/// Regenerate with:  python tools/reference_engine.py test/golden.json
DateTime wallOf(String iso) => DateTime.parse('${iso}Z');

Map<String, double> dmap(dynamic m, {List<String>? only}) => {
      for (final e in (m as Map<String, dynamic>).entries)
        if (only == null || only.contains(e.key)) e.key: (e.value as num).toDouble(),
    };

void main() {
  final golden = jsonDecode(File('test/golden.json').readAsStringSync())
      as Map<String, dynamic>;

  for (final key in golden.keys) {
    final g = golden[key] as Map<String, dynamic>;
    final inp = g['input'] as Map<String, dynamic>;
    final wall = wallOf(inp['wall'] as String);
    final tz = (inp['tz'] as num).toDouble();
    final lat = (inp['lat'] as num).toDouble();
    final lon = (inp['lon'] as num).toDouble();
    final lons = dmap(g['planets']);
    final asc = (g['asc'] as num).toDouble();

    group(key, () {
      test('Vimshottari mahadashas and 5-level running chain', () {
        final mahas = buildVimshottari(lons['Moon']!, wall);
        final exp = g['dasha'] as List<dynamic>;
        for (var i = 0; i < 9; i++) {
          expect(mahas[i].lord, exp[i][0]);
          expect(mahas[i].start.difference(wallOf(exp[i][1])).inMilliseconds.abs(), lessThan(2));
          expect(mahas[i].end.difference(wallOf(exp[i][2])).inMilliseconds.abs(), lessThan(2));
        }
        final when = wallOf(inp['when'] as String);
        final run = runningDasha(mahas, when);
        final expRun = g['runningDasha'] as List<dynamic>;
        expect(run.length, 5);
        for (var i = 0; i < 5; i++) {
          expect(run[i].lord, expRun[i][0]);
          expect(run[i].level, i + 1);
          expect(run[i].start.difference(wallOf(expRun[i][1])).inMilliseconds.abs(), lessThan(2));
          expect(run[i].end.difference(wallOf(expRun[i][2])).inMilliseconds.abs(), lessThan(2));
        }
      });

      test('Gulika / Mandi rising times (hours from birth)', () {
        final exp = g['upaOffsets'] as List<dynamic>;
        final up = upagrahaOffsets(wall, lat, lon, tz)!;
        expect(up.gulika, closeTo((exp[0] as num).toDouble(), 1e-6));
        expect(up.mandi, closeTo((exp[1] as num).toDouble(), 1e-6));
      });

      test('Chara dasha: years, direction, maha periods, running chain', () {
        final c = g['chara'] as Map<String, dynamic>;
        expect(charaForward(asc ~/ 30 % 12), c['forward']);
        final yrs = c['years'] as Map<String, dynamic>;
        for (var sg = 0; sg < 12; sg++) {
          expect(charaYears(sg, lons), yrs['$sg'], reason: 'sign $sg');
        }
        final mahas = buildCharaDasha(lons, asc, wall);
        final exp = c['mahas'] as List<dynamic>;
        expect(mahas.length, exp.length);
        for (var i = 0; i < exp.length; i++) {
          expect(mahas[i].sign, exp[i][0]);
          expect(mahas[i].start.difference(wallOf(exp[i][1])).inMilliseconds.abs(), lessThan(2));
          expect(mahas[i].end.difference(wallOf(exp[i][2])).inMilliseconds.abs(), lessThan(2));
        }
        final when = wallOf(inp['when'] as String);
        final run = runningChara(mahas, when);
        final expRun = c['running'] as List<dynamic>;
        expect(run.length, expRun.length);
        for (var i = 0; i < run.length; i++) {
          expect(run[i].sign, expRun[i][0]);
          expect(run[i].start.difference(wallOf(expRun[i][1])).inMilliseconds.abs(), lessThan(2));
          expect(run[i].end.difference(wallOf(expRun[i][2])).inMilliseconds.abs(), lessThan(2));
        }
      });

      test('Sub-periods exactly tile their parent', () {
        final mahas = buildVimshottari(lons['Moon']!, wall);
        var p = mahas[3];
        for (var lv = 1; lv < 5; lv++) {
          final kids = p.children;
          expect(kids.length, 9);
          expect(kids.first.start, p.start);
          expect(kids.last.end, p.end);
          p = kids[4];
        }
        expect(p.children, isEmpty);
      });

      test('Varga charts D1/D3/D9/D10', () {
        final vg = g['vargas'] as Map<String, dynamic>;
        for (final n in kShownVargas) {
          final exp = vg['D$n'] as Map<String, dynamic>;
          final chart = buildVarga(n, asc, lons);
          expect(chart.lagnaSign, exp['lagna']);
          expect(chart.lagnaDegree, closeTo((exp['lagnaDeg'] as num).toDouble(), 1e-6));
          (exp['deg'] as Map<String, dynamic>).forEach((p, d) {
            expect(chart.degrees[p]!, closeTo((d as num).toDouble(), 1e-6), reason: 'D$n $p deg');
          });
          (exp['planets'] as Map<String, dynamic>).forEach((p, s) {
            expect(chart.signs[p], s, reason: 'D$n $p');
          });
        }
      });

      test('Panchang', () {
        final e = g['panchang'] as Map<String, dynamic>;
        final p = computePanchang(lons['Sun']!, lons['Moon']!, wall, lat, lon, tz);
        expect(p.tithiNumber, e['tithiNumber']);
        expect(p.tithi, e['tithi']);
        expect(p.paksha, e['paksha']);
        expect(p.nakshatra, e['nakshatra']);
        expect(p.yoga, e['yoga']);
        expect(p.karana, e['karana']);
        expect(p.vara, e['vara']);
        expect(p.sunrise, closeTo((e['sunrise'] as num).toDouble(), 1e-6));
        expect(p.sunset, closeTo((e['sunset'] as num).toDouble(), 1e-6));
      });

      test('Ashtakavarga', () {
        final rasi = {for (final p in kSeven) p: lons[p]! ~/ 30};
        final av = computeAshtakavarga(rasi, asc ~/ 30);
        final e = g['ashtakavarga'] as Map<String, dynamic>;
        expect(av.sav, (e['sav'] as List).cast<int>());
        expect(av.sav.fold(0, (a, b) => a + b), 337);
        (e['bav'] as Map<String, dynamic>).forEach((p, row) {
          expect(av.bav[p], (row as List).cast<int>());
        });
      });

      test('Shadbala', () {
        final res = computeShadbala(ShadbalaInput(
          lon: dmap(g['planets'], only: kSeven),
          nodes: {
            'Rahu': (g['planets']['Rahu'] as num).toDouble(),
            'Ketu': (g['planets']['Ketu'] as num).toDouble(),
          },
          asc: asc,
          mc: (g['mc'] as num).toDouble(),
          ayanamsa: (g['ayanamsa'] as num).toDouble(),
          jd: (g['jd'] as num).toDouble(),
          tz: tz,
          lat: lat,
          lonGeo: lon,
          wall: wall,
        ));
        final sb = g['shadbala'] as Map<String, dynamic>;
        for (final p in kSeven) {
          final e = sb[p] as Map<String, dynamic>;
          final s = res.planets[p]!;
          void near(double a, String k) =>
              expect(a, closeTo((e[k] as num).toDouble(), 1e-4), reason: '$p $k');
          near(s.sthana, 'sthana');
          near(s.dig, 'dig');
          near(s.kala, 'kala');
          near(s.cheshta, 'cheshta');
          near(s.drik, 'drik');
          near(s.total, 'total');
        }
        final meta = sb['_meta'] as Map<String, dynamic>;
        expect(res.abdaLord, meta['abdaLord']);
        expect(res.masaLord, meta['masaLord']);
        expect(res.horaLord, meta['horaLord']);
      });

      test('Relations and Bhava bala', () {
        final rasi = {for (final p in kSeven) p: lons[p]! ~/ 30};
        final rel = computeRelations(rasi);
        (g['relations'] as Map<String, dynamic>).forEach((k, v) {
          final ab = k.split('>');
          final r = rel.of(ab[0], ab[1]);
          expect(r.natural, v['natural'], reason: k);
          expect(r.temporal, v['temporal'], reason: k);
          expect(r.compound, v['compound'], reason: k);
        });

        final res = computeShadbala(ShadbalaInput(
          lon: dmap(g['planets'], only: kSeven),
          nodes: {
            'Rahu': (g['planets']['Rahu'] as num).toDouble(),
            'Ketu': (g['planets']['Ketu'] as num).toDouble(),
          },
          asc: asc,
          mc: (g['mc'] as num).toDouble(),
          ayanamsa: (g['ayanamsa'] as num).toDouble(),
          jd: (g['jd'] as num).toDouble(),
          tz: tz,
          lat: lat,
          lonGeo: lon,
          wall: wall,
        ));
        final bb = computeBhavaBala(
          lon: dmap(g['planets'], only: kSeven),
          asc: asc,
          mc: (g['mc'] as num).toDouble(),
          shadbala: res,
        );
        final exp = g['bhavaBala'] as List<dynamic>;
        for (var i = 0; i < 12; i++) {
          final e = exp[i] as Map<String, dynamic>;
          expect(bb[i].lord, e['lord']);
          expect(bb[i].adhipati, closeTo((e['adhipati'] as num).toDouble(), 1e-4));
          expect(bb[i].dig, closeTo((e['dig'] as num).toDouble(), 1e-4));
          expect(bb[i].drishti, closeTo((e['drishti'] as num).toDouble(), 1e-4));
          expect(bb[i].total, closeTo((e['total'] as num).toDouble(), 1e-3));
        }
      });

      test('Planet insight (aspects, avasthas, karakas, dominance)', () {
        final res = computeShadbala(ShadbalaInput(
          lon: dmap(g['planets'], only: kSeven),
          nodes: {
            'Rahu': (g['planets']['Rahu'] as num).toDouble(),
            'Ketu': (g['planets']['Ketu'] as num).toDouble(),
          },
          asc: asc,
          mc: (g['mc'] as num).toDouble(),
          ayanamsa: (g['ayanamsa'] as num).toDouble(),
          jd: (g['jd'] as num).toDouble(),
          tz: tz,
          lat: lat,
          lonGeo: lon,
          wall: wall,
        ));
        final rasi = {for (final p in kSeven) p: lons[p]! ~/ 30};
        final av = computeAshtakavarga(rasi, asc ~/ 30);
        final ins = computeInsight(
          lon: lons,
          speed: dmap(g['speed']),
          asc: asc,
          shadbala: res,
          ashtakavarga: av,
          relations: computeRelations(rasi),
        );
        (g['insight'] as Map<String, dynamic>).forEach((p, e) {
          final i = ins[p]!;
          expect(i.house, e['house'], reason: p);
          expect(i.karaka7, e['karaka7'], reason: p);
          expect(i.karaka8, e['karaka8'], reason: p);
          expect(i.conjunct, (e['conjunct'] as List).cast<String>(), reason: p);
          final from = e['aspectsFrom'] as List<dynamic>;
          expect(i.aspectsFrom.length, from.length, reason: p);
          for (var k = 0; k < from.length; k++) {
            expect(i.aspectsFrom[k].house, from[k]['house'], reason: p);
            expect(i.aspectsFrom[k].planets, (from[k]['planets'] as List).cast<String>(), reason: p);
          }
          final to = e['aspectsTo'] as List<dynamic>;
          expect(i.aspectsTo.map((a) => '${a.planet}${a.offset}').toList(),
              to.map((a) => '${a['planet']}${a['offset']}').toList(), reason: p);
          if (kSeven.contains(p)) {
            expect(i.baladi, e['baladi'], reason: p);
            expect(i.jagradadi, e['jagradadi'], reason: p);
            expect(i.deeptadi, e['deeptadi'], reason: p);
            expect(i.dignity, e['dignity'], reason: p);
            expect(i.combust, e['combust'], reason: p);
            expect(i.vargottama, e['vargottama'], reason: p);
            expect(i.lordOf, (e['lordOf'] as List).cast<int>(), reason: p);
            expect(i.dominance!.rank, e['dominance']['rank'], reason: p);
            expect(i.dominance!.total,
                closeTo((e['dominance']['total'] as num).toDouble(), 1e-3), reason: p);
          }
        });
      });
    });
  }

  test('Vimshopaka weights add up to 20 and totals stay within 5..20', () {
    expect(kVimshopakaWeights.values.fold(0.0, (a, b) => a + b), 20);
    expect(kVimshopakaWeights.keys.toSet(), kShownVargas.toSet());
    expect(vargaDignityPoints('Sun', 4, computeRelations({for (final p in kSeven) p: 0})), 20);
  });

  test('Activation codes match the Python / WordPress issuer', () {
    const secret = 'test-secret-123';
    expect(makeActivationCode(secret, 30, 800, 0xABCDEF), '00F06-85BSQ-QZCRG-QPC40');
    expect(makeActivationCode(secret, 365, 801, 1), '05PG6-88000-0GK3E-V5M50');
    final c = parseActivationCode('00f06 85bsq qzcrg qpc40', secret)!;
    expect([c.days, c.issueDay, c.id], [30, 800, 0xABCDEF]);
    expect(parseActivationCode('00F06-85BSQ-QZCRG-QPC41', secret), isNull);
    expect(parseActivationCode('00F06-85BSQ-QZCRG-QPC40', 'other'), isNull);
    expect(parseActivationCode('00F06-85BSQ-QZCRG-QPC40', ''), isNull);
  });
}
