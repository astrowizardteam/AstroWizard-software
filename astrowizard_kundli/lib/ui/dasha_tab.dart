import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../engine/models.dart';
import 'dasha_navigator.dart';

final DateFormat _sec = DateFormat('dd MMM yyyy HH:mm:ss');

List<DashaNode> _nodes(List<DashaPeriod> l) => [
      for (final p in l)
        DashaNode(p.lord, p.start, p.end, p.level, () => _nodes(p.children)),
    ];

/// Vimshottari dasha down to Prana (level 5), browsed column by column.
class DashaTab extends StatelessWidget {
  final KundliChart chart;
  final bool embedded; // inside another scroll view
  const DashaTab({super.key, required this.chart, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final now = chart.birth.nowAtBirthZone();
    final running = runningDasha(chart.vimshottari, now);
    return ListView(
        shrinkWrap: embedded,
        physics: embedded ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.all(8),
        children: [
      if (running.isNotEmpty)
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Running now (${_sec.format(now)})',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(running.map((p) => p.lord).join(' › '),
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
        ),
      DashaNavigator(
        roots: _nodes(chart.vimshottari),
        levelNames: kDashaLevelNames,
        now: now,
        height: embedded ? 360 : 460,
      ),
    ]);
  }
}
