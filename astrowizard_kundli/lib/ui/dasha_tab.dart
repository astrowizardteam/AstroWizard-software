import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../engine/models.dart';
import 'period_tile.dart';

final DateFormat _day = DateFormat('dd MMM yyyy');
final DateFormat _sec = DateFormat('dd MMM yyyy HH:mm:ss');

String _fmt(DateTime t, int level) => level <= 2 ? _day.format(t) : _sec.format(t);

/// Vimshottari dasha down to Prana (level 5). Sub-periods are generated only
/// when a tile is expanded.
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
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Running now (${_sec.format(now)})',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final p in running)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${p.levelName}: ${p.lord}\n   ${_fmt(p.start, p.level)} → ${_fmt(p.end, p.level)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ]),
          ),
        ),
      _Periods(periods: chart.vimshottari, now: now),
    ]);
  }
}

bool _isNow(DashaPeriod p, DateTime now) => !now.isBefore(p.start) && now.isBefore(p.end);

class _Periods extends StatelessWidget {
  final List<DashaPeriod> periods;
  final DateTime now;
  const _Periods({required this.periods, required this.now});

  @override
  Widget build(BuildContext context) {
    final cur = periods.indexWhere((p) => _isNow(p, now));
    return SiblingList(
      count: periods.length,
      initialOpen: cur < 0 ? null : cur,
      itemBuilder: (ctx, i, open, toggle, prev, next) {
        final p = periods[i];
        return PeriodTile(
          key: ValueKey('v${p.level}-${p.lord}-${p.start.microsecondsSinceEpoch}'),
          title: '${p.lord} ${p.levelName}',
          subtitle: '${_fmt(p.start, p.level)} → ${_fmt(p.end, p.level)}',
          current: _isNow(p, now),
          open: open,
          expandable: p.level < 5,
          onToggle: toggle,
          onPrev: prev,
          onNext: next,
          indent: p.level == 1 ? 0 : 12,
          children: open && p.level < 5
              ? [_Periods(periods: p.children, now: now)]
              : const [],
        );
      },
    );
  }
}
