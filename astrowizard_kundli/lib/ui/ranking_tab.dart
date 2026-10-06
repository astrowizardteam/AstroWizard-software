import 'package:flutter/material.dart';

import '../engine/models.dart';
import 'chart_painters.dart';
import 'planet_sheet.dart';

/// Planets ranked from strongest to weakest by the dominance index, which
/// combines Shadbala, Ashtakavarga, dignity and net aspects.
class RankingTab extends StatelessWidget {
  final KundliChart chart;
  const RankingTab({super.key, required this.chart});

  static String verdict(double index) =>
      index >= 65 ? 'Strong' : (index >= 50 ? 'Moderate' : 'Weak');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ranked = [...kSeven]
      ..sort((a, b) => chart.insight[a]!.dominance!.rank
          .compareTo(chart.insight[b]!.dominance!.rank));

    Color colorOf(double idx) => idx >= 65
        ? Colors.green.shade700
        : (idx >= 50 ? Colors.orange.shade800 : scheme.error);

    return ListView(padding: const EdgeInsets.all(8), children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Text(
          'Strongest to weakest. Index (0-100) = Shadbala 40 + Ashtakavarga bindus in its sign 20 '
          '+ dignity 20 + net benefic/malefic aspects 20. Strong ≥ 65, Moderate 50-65, Weak < 50. '
          'Tap a planet for details. ᴿ retrograde, ᶜ combust.',
          style: TextStyle(fontSize: 12),
        ),
      ),
      for (final p in ranked)
        Builder(builder: (_) {
          final ins = chart.insight[p]!;
          final dom = ins.dominance!;
          final sb = chart.shadbala.planets[p]!;
          final idx = dom.total;
          return Card(
            child: InkWell(
              onTap: () => showPlanetSheet(context, chart, p),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: colorOf(idx),
                      child: Text('${dom.rank}', style: const TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('$p${planetMarks(chart, p)}',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Text('${idx.toStringAsFixed(0)}  ${verdict(idx)}',
                        style: TextStyle(color: colorOf(idx), fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (idx / 100).clamp(0.0, 1.0),
                    color: colorOf(idx),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    _chip('Shadbala', '${(sb.ratio * 100).toStringAsFixed(0)}%'),
                    _chip('Bindus', '${dom.bindus}/8'),
                    _chip('Dignity', ins.dignity!),
                    _chip('Aspects', sb.drik.toStringAsFixed(1)),
                    _chip('Avastha', '${ins.jagradadi} / ${ins.deeptadi}'),
                    _chip('House', '${ins.house}'),
                  ]),
                ]),
              ),
            ),
          );
        }),
      const Padding(
        padding: EdgeInsets.all(8),
        child: Text('Rahu and Ketu are not ranked (no Shadbala).', style: TextStyle(fontSize: 12)),
      ),
    ]);
  }

  Widget _chip(String k, String v) => Text.rich(TextSpan(children: [
        TextSpan(text: '$k: ', style: const TextStyle(fontSize: 12)),
        TextSpan(text: v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]));
}
