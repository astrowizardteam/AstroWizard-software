import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/ephemeris.dart';
import '../engine/models.dart';
import 'chart_painters.dart';

/// Circular chart with three rings that all share the birth lagna as house 1:
/// inner = D1 (Rasi), middle = D9 (Navamsa), outer = transit (gochara).
/// Houses run anticlockwise from the top.
class SudarshanPainter extends CustomPainter {
  final int lagnaSign; // sign shown as house 1
  final int ascHouse; // house holding the real ascendant
  final List<List<String>> d1; // per house (index 0 = house 1)
  final List<List<String>> d9;
  final List<List<String>> transit;
  final Color lineColor;
  final Color textColor;
  final List<Color> ringColors;

  SudarshanPainter({
    required this.lagnaSign,
    required this.ascHouse,
    required this.d1,
    required this.d9,
    required this.transit,
    required this.lineColor,
    required this.textColor,
    required this.ringColors,
  });

  static double _rad(double deg) => deg * math.pi / 180;

  /// Canvas angle (radians) of the centre of house [h] (1..12).
  static double centerAngle(int h) => _rad(-90.0 - 30.0 * (h - 1));

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(s / 2, s / 2);
    final outer = s / 2 - 2;
    // radii: hole, D1, D9, transit, sign band
    final radii = <double>[
      outer * 0.16,
      outer * 0.42,
      outer * 0.68,
      outer * 0.92,
      outer,
    ];
    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // ring fills
    for (var i = 0; i < 3; i++) {
      final path = Path()
        ..addOval(Rect.fromCircle(center: c, radius: radii[i + 1]))
        ..addOval(Rect.fromCircle(center: c, radius: radii[i]))
        ..fillType = PathFillType.evenOdd;
      canvas.drawPath(path, Paint()..color = ringColors[i]);
    }
    for (final r in radii) {
      canvas.drawCircle(c, r, line);
    }
    // 12 radial separators
    for (var h = 0; h < 12; h++) {
      final a = centerAngle(1) - _rad(15) - _rad(30.0 * h);
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * radii[0],
          c + Offset(math.cos(a), math.sin(a)) * radii[4], line);
    }

    final small = TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: s * 0.03);
    final plan = TextStyle(color: textColor, fontSize: s * 0.03, fontWeight: FontWeight.w600);
    final rings = [d1, d9, transit];

    for (var h = 1; h <= 12; h++) {
      final a = centerAngle(h);
      final dir = Offset(math.cos(a), math.sin(a));
      // sign band: house number and sign
      final sign = (lagnaSign + h - 1) % 12;
      _label(canvas, '$h\n${kSignsShort[sign]}${h == ascHouse ? '\nAsc' : ''}', c + dir * ((radii[3] + radii[4]) / 2), small, s * 0.1);
      for (var r = 0; r < 3; r++) {
        final items = rings[r][h - 1];
        if (items.isEmpty) continue;
        final mid = (radii[r] + radii[r + 1]) / 2;
        _label(canvas, items.join(' '), c + dir * mid, plan, s * 0.115 + r * s * 0.04);
      }
    }
  }

  void _label(Canvas canvas, String text, Offset center, TextStyle style, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant SudarshanPainter old) =>
      old.lagnaSign != lagnaSign || old.ascHouse != ascHouse || old.transit != transit || old.d1 != d1 || old.d9 != d9;
}

/// Sudarshan Chakra drawing. House 1 is the birth lagna rotated by [rot]
/// houses; all three rings use the same base sign.
class SudarshanView extends StatelessWidget {
  final KundliChart chart;
  final DateTime instant; // real UTC instant of the transit ring
  final int rot;
  const SudarshanView({super.key, required this.chart, required this.instant, this.rot = 0});

  List<List<String>> _group(Map<String, int> signs, int base,
      String Function(String) marks, double Function(String) degOf) {
    final out = List.generate(12, (_) => <String>[]);
    for (final n in kPlanetOrder) {
      final sg = signs[n];
      if (sg == null) continue;
      out[(sg - base) % 12].add('${kPlanetShort[n]} ${degOf(n).floor()}°${marks(n)}');
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lagna = chart.lagnaSign;
    final base = (lagna + rot) % 12;
    final d9 = chart.vargas[9]!;
    final tr = EphemerisEngine.transit(instant, lagna);

    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: SudarshanPainter(
          lagnaSign: base,
          ascHouse: (lagna - base) % 12 + 1,
          d1: _group({for (final e in chart.planets.entries) e.key: e.value.signIndex}, base,
              (n) => planetMarks(chart, n), (n) => chart.planets[n]!.degreeInSign),
          d9: _group(d9.signs, base, (n) => planetMarks(chart, n), (n) => d9.degrees[n] ?? 0),
          transit: _group({for (final e in tr.entries) e.key: e.value.signIndex}, base,
              (n) => transitMarks(tr[n]!), (n) => tr[n]!.degreeInSign),
          lineColor: scheme.primary,
          textColor: scheme.onSurface,
          ringColors: [
            scheme.primaryContainer.withValues(alpha: 0.55),
            scheme.secondaryContainer.withValues(alpha: 0.55),
            scheme.tertiaryContainer.withValues(alpha: 0.55),
          ],
        ),
      ),
    );
  }
}
