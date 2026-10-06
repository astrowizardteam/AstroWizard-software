import 'package:flutter/material.dart';

import '../engine/models.dart';
import 'chart_painters.dart';

String _ord(int n) => switch (n) { 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${n}th' };

const Map<String, String> _baladiNote = {
  'Bala': 'infant (about quarter results)',
  'Kumara': 'adolescent (half results)',
  'Yuva': 'youth (full results)',
  'Vriddha': 'old (reduced results)',
  'Mrita': 'dead (very weak results)',
};
const Map<String, String> _jagradNote = {
  'Jagrat': 'awake - full results (own / exalted sign)',
  'Swapna': 'dreaming - medium results (friendly / neutral sign)',
  'Sushupti': 'asleep - poor results (enemy / debilitated sign)',
};
const Map<String, String> _deeptNote = {
  'Deepta': 'exalted - bright, very effective',
  'Swastha': 'own sign - comfortable, steady',
  'Mudita': 'great friend\'s sign - delighted',
  'Shanta': 'friend\'s sign - peaceful',
  'Dina': 'neutral sign - ordinary, needs support',
  'Dukhita': 'enemy\'s sign - distressed',
  'Vikala': 'great enemy\'s sign - crippled',
  'Khala': 'debilitated - weak, troubled',
  'Kopita': 'combust - burnt by the Sun, angry',
};

void showPlanetSheet(BuildContext context, KundliChart chart, String planet) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, controller) => _PlanetDetail(
          chart: chart, planet: planet, controller: controller),
    ),
  );
}

class _PlanetDetail extends StatelessWidget {
  final KundliChart chart;
  final String planet;
  final ScrollController controller;
  const _PlanetDetail(
      {required this.chart, required this.planet, required this.controller});

  @override
  Widget build(BuildContext context) {
    final pos = chart.planets[planet]!;
    final ins = chart.insight[planet]!;
    final theme = Theme.of(context);
    Widget head(String t) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 6),
          child: Text(t, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
        );
    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 118, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(v)),
          ]),
        );

    final d = pos.degreeInSign;
    return ListView(controller: controller, padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
      Text('$planet${planetMarks(chart, planet)}', style: theme.textTheme.headlineSmall),
      Text('${pos.sign} ${d.floor()}°${((d - d.floor()) * 60).floor().toString().padLeft(2, '0')}\'  •  '
          '${pos.nakshatra} pada ${pos.pada} (lord ${pos.nakshatraLord})  •  House ${ins.house}'),

      // ---------------------------------------------------------- 1 influence
      head('1. Influence and aspects'),
      line('Sits in', 'House ${ins.house} (${kSigns[ins.sign]})'),
      if (ins.lordOf != null)
        line('Lord of', 'House ${ins.lordOf!.join(' and ')}'),
      line('Conjunct', ins.conjunct.isEmpty ? 'none' : ins.conjunct.join(', ')),
      const SizedBox(height: 8),
      Text('Aspects TO houses (this planet looks at):', style: theme.textTheme.titleSmall),
      for (final a in ins.aspectsFrom)
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 3),
          child: Text('• ${_ord(a.offset)} aspect → House ${a.house} (${kSigns[(chart.lagnaSign + a.house - 1) % 12]})'
              '${a.planets.isEmpty ? '' : ': ${a.planets.join(', ')}'}'),
        ),
      const SizedBox(height: 8),
      Text('Aspected BY (looking at this planet):', style: theme.textTheme.titleSmall),
      if (ins.aspectsTo.isEmpty)
        const Padding(padding: EdgeInsets.only(left: 8, top: 3), child: Text('• none')),
      for (final a in ins.aspectsTo)
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 3),
          child: Text('• ${a.planet} - ${_ord(a.offset)} aspect'
              '${a.virupa == null ? '' : '  (${a.virupa!.toStringAsFixed(0)} virupas)'}'),
        ),

      // ----------------------------------------------------------- 2 avastha
      head('2. Avastha (state)'),
      if (ins.baladi == null)
        const Text('Avasthas are defined for the seven planets (Sun to Saturn).')
      else ...[
        line('Baladi', '${ins.baladi} - ${_baladiNote[ins.baladi]}'),
        line('Jagradadi', '${ins.jagradadi} - ${_jagradNote[ins.jagradadi]}'),
        line('Deeptadi', '${ins.deeptadi} - ${_deeptNote[ins.deeptadi]}'),
        line('Dignity', ins.dignity!),
        line('Combust', ins.combust! ? 'Yes' : 'No'),
        line('Retrograde', pos.retrograde ? 'Yes' : 'No'),
        line('Vargottama', ins.vargottama! ? 'Yes (same sign in D1 and D9)' : 'No'),
      ],

      // ------------------------------------------------------------ 3 karaka
      head('3. Chara karaka (Jaimini)'),
      line('7-planet scheme', ins.karaka7 ?? '- (not used)'),
      line('8-planet scheme', ins.karaka8 ?? '- (not used)'),
      const Text('Ranked by degrees within the sign; the highest degree is the Atmakaraka. '
          'The 8-planet scheme includes Rahu (measured from the end of its sign).',
          style: TextStyle(fontSize: 12)),

      // --------------------------------------------------------- 4 dominance
      head('4. Dominance in the chart'),
      if (ins.dominance == null)
        const Text('Dominance is calculated for the seven planets.')
      else
        _dominance(context, ins),
    ]);
  }

  Widget _dominance(BuildContext context, PlanetInsight ins) {
    final dom = ins.dominance!;
    final sb = chart.shadbala.planets[planet]!;
    Widget bar(String label, double v, double max, String extra) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$label: ${v.toStringAsFixed(1)} / ${max.toStringAsFixed(0)}  $extra',
                style: const TextStyle(fontSize: 13)),
            LinearProgressIndicator(value: (v / max).clamp(0.0, 1.0)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Dominance index ${dom.total.toStringAsFixed(0)} / 100  •  rank ${dom.rank} of 7',
          style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      bar('Shadbala', dom.shadbala, 40, '(${(sb.ratio * 100).toStringAsFixed(0)}% of optimum)'),
      bar('Ashtakavarga', dom.ashtakavarga, 20, '(${dom.bindus} bindus in its sign)'),
      bar('Dignity', dom.dignity, 20, '(${ins.dignity})'),
      bar('Aspects', dom.aspects, 20, '(net Drik bala ${sb.drik.toStringAsFixed(1)})'),
      const SizedBox(height: 4),
      const Text('The index is an app-defined summary: Shadbala 40 + Ashtakavarga 20 + '
          'dignity 20 + net benefic/malefic aspects 20. It is not a classical figure.',
          style: TextStyle(fontSize: 12)),
    ]);
  }
}
