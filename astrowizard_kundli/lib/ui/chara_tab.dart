import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../engine/models.dart';
import 'dasha_navigator.dart';

final DateFormat _sec = DateFormat('dd MMM yyyy HH:mm:ss');

List<DashaNode> _nodes(List<CharaPeriod> l) => [
      for (final p in l)
        DashaNode(
          p.level == 1
              ? '${p.name} · ${(p.end.difference(p.start).inMicroseconds / 31557600e6).round()} yrs'
              : p.name,
          p.start,
          p.end,
          p.level,
          () => _nodes(p.children),
        ),
    ];

/// Jaimini Chara dasha (K.N. Rao), counted from the lagna, down to Prana (level 5).
class CharaDashaTab extends StatelessWidget {
  final KundliChart chart;
  const CharaDashaTab({super.key, required this.chart});

  @override
  Widget build(BuildContext context) {
    final now = chart.birth.nowAtBirthZone();
    final running = runningChara(chart.chara, now);
    final theme = Theme.of(context);
    final fwd = chart.chara.first.forward;
    return ListView(padding: const EdgeInsets.all(8), children: [
      if (running.isNotEmpty)
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Running now (${_sec.format(now)})', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(running.map((p) => p.name).join(' › '), style: theme.textTheme.bodyMedium),
            ]),
          ),
        ),
      DashaNavigator(
        roots: _nodes(chart.chara),
        levelNames: kCharaLevelNames,
        now: now,
        height: 460,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Text(
          'Chara dasha from lagna ${kSigns[chart.lagnaSign]} · '
          '${fwd ? 'direct' : 'reverse'} order · K.N. Rao method.\n'
          'Antardasha order (starts from the parent sign, same direction) and the '
          'second cycle (12 − years) follow common practice; schools differ.',
          style: theme.textTheme.bodySmall,
        ),
      ),
    ]);
  }
}
