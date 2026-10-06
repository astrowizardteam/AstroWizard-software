import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../engine/models.dart';
import 'period_tile.dart';

final DateFormat _day = DateFormat('dd MMM yyyy');
final DateFormat _sec = DateFormat('dd MMM yyyy HH:mm:ss');

String _fmt(DateTime t, int level) => level <= 2 ? _day.format(t) : _sec.format(t);

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
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Text(
          'Chara dasha from lagna ${kSigns[chart.lagnaSign]} · '
          '${fwd ? 'direct' : 'reverse'} order · K.N. Rao method.\n'
          'Antardasha order (starts from the parent sign, same direction) and the '
          'second cycle (12 − years) follow common practice; schools differ.',
          style: theme.textTheme.bodySmall,
        ),
      ),
      if (running.isNotEmpty)
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Running now (${_sec.format(now)})', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final p in running)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${p.levelName}: ${p.name}\n   ${_fmt(p.start, p.level)} → ${_fmt(p.end, p.level)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ]),
          ),
        ),
      _Periods(periods: chart.chara, now: now),
    ]);
  }
}

bool _isNow(CharaPeriod p, DateTime now) => !now.isBefore(p.start) && now.isBefore(p.end);

class _Periods extends StatelessWidget {
  final List<CharaPeriod> periods;
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
        final years = (p.end.difference(p.start).inMicroseconds / 31557600e6)
            .toStringAsFixed(p.level == 1 ? 0 : 3);
        return PeriodTile(
          key: ValueKey('c${p.level}-${p.sign}-${p.start.microsecondsSinceEpoch}'),
          title: p.level == 1 ? '${p.name} · $years yrs' : p.name,
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
