import 'package:flutter/material.dart';

import '../engine/guide_data.dart';
import '../engine/models.dart';

/// Dasha guide: the greater (higher-level) dasha lord sets the field of function,
/// the lower (next-level) lord acts inside it. Works for any pair of dasha levels. The user picks the houses of both lords —
/// either the houses a lord owns or the house it sits in — and sees how the
/// significations intermingle. Nothing is pre-selected; with a chart open the
/// running pair of any two consecutive levels can be loaded with one tap.
class GuideScreen extends StatefulWidget {
  final KundliChart? chart;
  const GuideScreen({super.key, this.chart});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _Lord {
  String? planet;
  bool owns = true; // true = lord of house(s), false = sitting in house
  final Set<int> houses = {};
}

class _GuideScreenState extends State<GuideScreen> {
  final _md = _Lord(), _ad = _Lord(); // greater / lower lord
  int _level = 1; // running pair loaded = level _level and _level + 1

  static const _planets = [...kSeven, 'Rahu', 'Ketu'];

  /// Houses a planet owns (lagna sign = house 1) or sits in.
  Set<int> _housesOf(String p, bool owns) {
    final c = widget.chart;
    if (c == null) return {};
    if (!owns || p == 'Rahu' || p == 'Ketu') return {c.planets[p]!.house};
    return {
      for (var s = 0; s < 12; s++)
        if (kSignLords[s] == p) (s - c.lagnaSign) % 12 + 1,
    };
  }

  void _fill(_Lord l) {
    if (l.planet == null || widget.chart == null) return;
    l.houses
      ..clear()
      ..addAll(_housesOf(l.planet!, l.owns));
  }

  void _useRunning() {
    final c = widget.chart!;
    final run = runningDasha(c.vimshottari, c.birth.nowAtBirthZone());
    if (run.length < _level + 1) return;
    setState(() {
      _md.planet = run[_level - 1].lord;
      _ad.planet = run[_level].lord;
      _fill(_md);
      _fill(_ad);
    });
  }

  Widget _lordCard(String title, _Lord l) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (widget.chart != null) ...[
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              value: l.planet,
              key: ValueKey('${title}_${l.planet}'),
              decoration: const InputDecoration(labelText: 'Planet (optional, fills houses)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('— none —')),
                for (final p in _planets) DropdownMenuItem<String?>(value: p, child: Text(p)),
              ],
              onChanged: (v) => setState(() {
                l.planet = v;
                _fill(l);
              }),
            ),
          ],
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: true, label: Text('Lord of house')),
              ButtonSegment(value: false, label: Text('Sitting in house')),
            ],
            selected: {l.owns},
            onSelectionChanged: (s) => setState(() {
              l.owns = s.first;
              if (l.planet != null) _fill(l);
            }),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 0, children: [
            for (var h = 1; h <= 12; h++)
              FilterChip(
                label: Text('$h'),
                selected: l.houses.contains(h),
                onSelected: (v) => setState(() => v ? l.houses.add(h) : l.houses.remove(h)),
              ),
          ]),
        ]),
      ),
    );
  }

  String _who(_Lord l) {
    final hs = (l.houses.toList()..sort()).join(', ');
    final what = l.owns ? 'lord of house' : 'sitting in house';
    return '${l.planet ?? 'Lord'} $what $hs';
  }

  Widget _houseBlock(String label, int h) {
    final i = kHouseInfo[h - 1];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: '$label — House $h · ${i.name} (${i.theme})\n',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        TextSpan(text: i.keywords.join('; ')),
        TextSpan(
            text: '\n${kindsText(i.kinds)}',
            style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
      ])),
    );
  }

  Widget _result() {
    final theme = Theme.of(context);
    final mds = _md.houses.toList()..sort();
    final ads = _ad.houses.toList()..sort();
    if (mds.isEmpty || ads.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Select at least one house for the greater lord and for the '
            'lower lord to see the combined reading.',
            style: theme.textTheme.bodyMedium),
      );
    }
    final pairs = <(int, int)>[
      for (final m in mds)
        for (final a in ads) (m, a),
    ];
    final shown = pairs.take(6).toList();
    final rel = widget.chart != null && _md.planet != null && _ad.planet != null &&
            _md.planet != _ad.planet &&
            kSeven.contains(_md.planet) && kSeven.contains(_ad.planet)
        ? widget.chart!.relations.of(_md.planet!, _ad.planet!)
        : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text('${_who(_md)}  →  ${_who(_ad)}',
              style: theme.textTheme.titleSmall),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Field of function (greater lord decides)', style: theme.textTheme.titleSmall),
            for (final m in mds) _houseBlock('Greater lord', m),
            const Divider(height: 24),
            Text('Acts inside that field (lower lord)', style: theme.textTheme.titleSmall),
            for (final a in ads) _houseBlock('Lower lord', a),
          ]),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Intermingled reading', style: theme.textTheme.titleSmall),
            for (final (m, a) in shown) ...[
              const SizedBox(height: 10),
              Text('Greater lord house $m × lower lord house $a',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(_mingle(m, a)),
              const SizedBox(height: 4),
              Text(kFromMd[(a - m) % 12 + 1]!, style: theme.textTheme.bodySmall),
              if (axisText((m - a) % 12 + 1).isNotEmpty)
                Text(axisText((m - a) % 12 + 1), style: theme.textTheme.bodySmall),
            ],
            if (pairs.length > shown.length)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${pairs.length - shown.length} more combinations not shown. '
                    'Select fewer houses to see each one.',
                    style: theme.textTheme.bodySmall),
              ),
            if (rel != null) ...[
              const Divider(height: 24),
              Text('Relation of the two lords (in this chart)',
                  style: theme.textTheme.titleSmall),
              Text('${_ad.planet} regards ${_md.planet} as '
                  '${compoundName(rel.compound)} '
                  '(natural ${rel.natural}, temporal ${rel.temporal}). '
                  'Friendly lords give smoother results; enemies create friction.'),
            ],
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
        child: Text(
          'Principle: the greater dasha lord sets the area of life and the lower dasha lord operates within it. '
          'The actual outcome also depends on each planet\'s strength, dignity, nature, aspects, '
          'conjunctions and the nakshatra lordship — check the Planets and Strength tabs. '
          'Significations follow classical texts (BPHS, Phaladeepika, Saravali) in the app\'s own '
          'words; edit lib/engine/guide_data.dart to change the significations.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        ),
      ),
    ]);
  }

  /// Three bullet points joining the lower lord's themes with the greater lord's field.
  String _mingle(int m, int a) {
    final km = kHouseInfo[m - 1].keywords, ka = kHouseInfo[a - 1].keywords;
    return [
      for (var i = 0; i < 3; i++) '• ${ka[i]} (house $a) expressed through ${km[i]} (house $m)',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dasha guide')),
      body: ListView(padding: const EdgeInsets.all(8), children: [
        if (widget.chart != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.timelapse),
                  label: const Text('Load running dasha'),
                  onPressed: _useRunning,
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _level,
                  items: [
                    for (var l = 1; l <= 4; l++)
                      DropdownMenuItem(value: l, child: Text('Level $l → ${l + 1}')),
                  ],
                  onChanged: (v) => setState(() => _level = v ?? 1),
                ),
              ]),
            ),
          ),
        _lordCard('1 · Greater dasha lord', _md),
        _lordCard('2 · Lower dasha lord', _ad),
        _result(),
      ]),
    );
  }
}
