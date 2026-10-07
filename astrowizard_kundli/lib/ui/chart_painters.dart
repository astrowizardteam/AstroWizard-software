import 'package:flutter/material.dart';

import '../engine/models.dart';

void _text(Canvas canvas, String text, Offset center, TextStyle style,
    {double maxWidth = 200}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

/// Superscript marks after a planet code: ᴿ retrograde, ᶜ combust.
String planetMarks(KundliChart chart, String name) {
  final retro = chart.planets[name]?.retrograde ?? false;
  final combust = chart.insight[name]?.combust ?? false;
  final isNode = name == 'Rahu' || name == 'Ketu';
  return '${retro && !isNode ? 'ᴿ' : ''}${combust ? 'ᶜ' : ''}';
}

/// Planet label with degree and marks, e.g. "Su 14°ᴿ". [degree] is the degree
/// inside the sign of the chart being drawn.
String planetLabel(KundliChart chart, String name, double degree) =>
    '${kPlanetShort[name] ?? name} ${degree.floor()}°${planetMarks(chart, name)}';

/// Extra lines under each planet in the chart.
class LabelOptions {
  final bool nakshatra;
  final bool lord;
  const LabelOptions({this.nakshatra = false, this.lord = false});
}

String _nakText(double lon, LabelOptions o) {
  final idx = (lon ~/ kNakshatraSpan) % 27;
  final pada = ((lon % kNakshatraSpan) ~/ (kNakshatraSpan / 4)) + 1;
  final parts = <String>[
    if (o.nakshatra) '${kNakshatraAbbr[idx]}-$pada',
    if (o.lord) kPlanetShort[kDashaOrder[idx % 9]]!,
  ];
  return parts.join(' ');
}

/// Planet labels grouped by house (1..12) when sign [base] is house 1.
/// Each label: code, degree inside the shown sign and marks, plus an optional
/// second line with nakshatra-pada and nakshatra lord.
Map<int, List<String>> buildLabels({
  required Map<String, int> signs,
  required Map<String, double> degrees,
  required Map<String, double> nakLons,
  required int base,
  required String Function(String) marks,
  LabelOptions options = const LabelOptions(),
  bool compact = false, // planet code and marks only (small charts)
}) {
  final out = <int, List<String>>{};
  for (final name in kChartBodies) {
    final sign = signs[name];
    if (sign == null) continue;
    final house = (sign - base) % 12 + 1;
    final nak = compact ? '' : _nakText(nakLons[name]!, options);
    final deg = compact ? '' : ' ${(degrees[name] ?? 0).floor()}°';
    final label = '${kPlanetShort[name] ?? name}$deg${marks(name)}'
        '${nak.isEmpty ? '' : '\n$nak'}';
    out.putIfAbsent(house, () => []).add(label);
  }
  return out;
}

/// Natal (D1 / varga) labels.
Map<int, List<String>> buildHouseLabels(KundliChart chart, VargaChart varga, int base,
    [LabelOptions options = const LabelOptions(), bool compact = false]) =>
    buildLabels(
      signs: varga.signs,
      degrees: varga.degrees,
      nakLons: {for (final e in chart.planets.entries) e.key: e.value.longitude},
      base: base,
      marks: (n) => planetMarks(chart, n),
      options: options,
      compact: compact,
    );

/// Transit labels: current positions drawn from the same base sign.
Map<int, List<String>> buildTransitLabels(
    Map<String, PlanetPosition> tr, int base,
    [LabelOptions options = const LabelOptions(), bool compact = false]) =>
    buildLabels(
      signs: {for (final e in tr.entries) e.key: e.value.signIndex},
      degrees: {for (final e in tr.entries) e.key: e.value.degreeInSign},
      nakLons: {for (final e in tr.entries) e.key: e.value.longitude},
      base: base,
      marks: (n) => transitMarks(tr[n]!),
      options: options,
      compact: compact,
    );

String transitMarks(PlanetPosition p) {
  final isNode = p.name == 'Rahu' || p.name == 'Ketu';
  return p.retrograde && !isNode ? 'ᴿ' : '';
}

/// North Indian (diamond) chart. House 1 is always the top diamond; signs
/// rotate according to the lagna of the chart being drawn.
class NorthIndianPainter extends CustomPainter {
  final int lagnaSign; // sign shown as house 1
  final int ascHouse; // house holding the real ascendant
  final String ascLabel;
  final Map<int, List<String>> labelsByHouse;
  final Color lineColor;
  final Color textColor;
  final double fontScale; // >1 for small charts

  NorthIndianPainter({
    required this.lagnaSign,
    this.ascHouse = 1,
    this.ascLabel = 'Asc',
    required this.labelsByHouse,
    required this.lineColor,
    required this.textColor,
    this.fontScale = 1,
  });

  // Centre of each house in unit-square coordinates (index 0 = house 1).
  static const List<Offset> _centers = [
    Offset(.50, .25), Offset(.25, .083), Offset(.083, .25), Offset(.25, .50),
    Offset(.083, .75), Offset(.25, .917), Offset(.50, .75), Offset(.75, .917),
    Offset(.917, .75), Offset(.75, .50), Offset(.917, .25), Offset(.75, .083),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), paint);
    canvas.drawLine(Offset.zero, Offset(s, s), paint);
    canvas.drawLine(Offset(s, 0), Offset(0, s), paint);
    final d = Path()
      ..moveTo(s / 2, 0)
      ..lineTo(s, s / 2)
      ..lineTo(s / 2, s)
      ..lineTo(0, s / 2)
      ..close();
    canvas.drawPath(d, paint);

    final small =
        TextStyle(color: textColor.withValues(alpha: 0.55), fontSize: s * 0.040 * fontScale);
    final plan = TextStyle(
        color: textColor, fontSize: s * 0.042 * fontScale, fontWeight: FontWeight.w600);

    for (var h = 1; h <= 12; h++) {
      final c = _centers[h - 1] * s;
      final sign = (lagnaSign + h - 1) % 12;
      final lines = <String>[if (h == ascHouse) ascLabel, ...(labelsByHouse[h] ?? const <String>[])];
      final painters = [
        for (final t in lines)
          TextPainter(
            text: TextSpan(text: t, style: t.contains('\n') ? plan.copyWith(fontSize: s * 0.036 * fontScale) : plan),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: s * 0.27),
      ];
      final total = painters.fold<double>(0, (a, p) => a + p.height);
      var y = c.dy - total / 2;
      final numP = TextPainter(
        text: TextSpan(text: '${sign + 1}', style: small),
        textDirection: TextDirection.ltr,
      )..layout();
      numP.paint(canvas, Offset(c.dx - numP.width / 2, y - numP.height - 1));
      for (final p in painters) {
        p.paint(canvas, Offset(c.dx - p.width / 2, y));
        y += p.height;
      }
    }
  }

  @override
  bool shouldRepaint(covariant NorthIndianPainter old) =>
      old.fontScale != fontScale ||
      old.lagnaSign != lagnaSign ||
      old.ascHouse != ascHouse ||
      old.labelsByHouse != labelsByHouse;
}
