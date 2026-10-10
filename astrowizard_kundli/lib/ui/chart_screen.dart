import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../engine/cities.dart';
import '../engine/ephemeris.dart';
import '../engine/models.dart';
import '../engine/vimshopaka.dart';
import '../storage.dart';
import '../location.dart';
import '../transfer.dart';
import '../xml_io.dart';
import 'guide_screen.dart';
import 'chart_painters.dart';
import 'chara_tab.dart';
import 'dasha_tab.dart';
import 'input_screen.dart';
import 'planet_sheet.dart';
import 'ranking_tab.dart';
import 'sudarshan.dart';

class ChartScreen extends StatefulWidget {
  final BirthData birth;
  final String? savedId; // null = not saved yet
  const ChartScreen({super.key, required this.birth, this.savedId});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  late BirthData _orig = widget.birth; // details as entered / last saved
  Duration _delta = Duration.zero; // birth-time rectification shift
  late KundliChart _chart = EphemerisEngine.compute(_orig);
  late String? _id = widget.savedId;
  BirthData? _savedBirth; // what is stored right now (null = never saved)
  int _nav = 0;
  int _planetsView = 0;
  int _strengthView = 0;
  int _dashaView = 0;
  int _second = 9; // small chart choices (D1 is always the large one)
  int _third = 100;
  bool _btr = false;
  int _rot = 0; // chart rotation: house shown as the 1st
  bool _showNak = false;
  bool _showLord = false;
  DateTime _transit = DateTime.now().toUtc();
  ({double lat, double lon})? _here; // device location for the transit ascendant
  bool _locating = false;
  String? _hereName; // city chosen by hand (null = GPS)
  bool _trFromHere = false; // draw the transit chart from the transit lagna

  BirthData get _birth => _orig.copyWith(wall: _orig.wall.add(_delta));

  @override
  void initState() {
    super.initState();
    if (widget.savedId != null) _savedBirth = widget.birth;
    // The transit chart needs the place where the person is: ask once on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _here == null) _useMyLocation(quiet: true);
    });
  }

  bool get _dirty => _savedBirth == null || _savedBirth!.wall != _birth.wall ||
      _savedBirth!.name != _birth.name || _savedBirth!.place != _birth.place ||
      _savedBirth!.latitude != _birth.latitude || _savedBirth!.longitude != _birth.longitude ||
      _savedBirth!.tzHours != _birth.tzHours;

  void _recompute() => setState(() => _chart = EphemerisEngine.compute(_birth));

  void _shift(Duration d) {
    _delta += d;
    _recompute();
  }

  Future<void> _save() async {
    final b = _birth;
    final id = await ChartStore.upsert(_id, b);
    if (!mounted) return;
    setState(() {
      _id = id;
      _savedBirth = b;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Saved'), duration: Duration(seconds: 1)));
  }

  Future<void> _edit() async {
    final b = await Navigator.push<BirthData>(
        context, MaterialPageRoute(builder: (_) => InputScreen(initial: _birth)));
    if (b == null) return;
    _orig = b;
    _delta = Duration.zero;
    _recompute();
  }

  Future<void> _close() async {
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close chart?'),
        content: Text(_savedBirth == null
            ? 'This chart is not saved.'
            : 'You have unsaved changes (edited details or shifted birth time).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Discard')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
        ],
      ),
    );
    if (choice == 'save') await _save();
    if ((choice == 'save' || choice == 'discard') && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = _chart;
    final df = DateFormat('dd MMM yyyy, HH:mm:ss');
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: _close),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.birth.name.isEmpty ? 'Kundli' : c.birth.name,
                style: Theme.of(context).textTheme.titleMedium),
            Text('${df.format(c.birth.wall)} • ${c.birth.place}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
                overflow: TextOverflow.ellipsis),
          ]),
          actions: [
            IconButton(
              icon: Icon(Icons.schedule, color: _btr ? scheme.primary : null),
              tooltip: 'Birth time rectification',
              onPressed: () => setState(() => _btr = !_btr),
            ),
            IconButton(
              icon: Icon(_dirty ? Icons.bookmark_add_outlined : Icons.bookmark),
              tooltip: _dirty ? 'Save' : 'Saved',
              onPressed: _dirty ? _save : null,
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _edit();
                if (v == 'close') _close();
                if (v == 'sharexml') {
                  shareXmlFile(
                      chartsToXml([SavedChart(_id ?? 'x', _birth)]),
                      _birth.name.isEmpty ? 'kundli' : _birth.name);
                }
                if (v == 'guide') {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => GuideScreen(chart: _chart)));
                }
                if (v == 'share') {
                  shareJsonFile(ChartStore.exportOne(_birth, id: _id),
                      _birth.name.isEmpty ? 'kundli' : _birth.name);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'share', child: Text('Share this chart (JSON)')),
                PopupMenuItem(value: 'sharexml', child: Text('Share this chart (XML)')),
                PopupMenuItem(value: 'guide', child: Text('Dasha guide')),
                PopupMenuItem(value: 'edit', child: Text('Edit details')),
                PopupMenuItem(value: 'close', child: Text('Close chart')),
              ],
            ),
          ],
        ),
        body: Column(children: [
          if (_btr) _btrBar(context, c),
          Expanded(child: _page(context, c)),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _nav,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => setState(() => _nav = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.donut_large_outlined), selectedIcon: Icon(Icons.donut_large), label: 'Chart'),
            NavigationDestination(icon: Icon(Icons.public_outlined), selectedIcon: Icon(Icons.public), label: 'Planets'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Strength'),
            NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: 'Dasha'),
            NavigationDestination(icon: Icon(Icons.wb_twilight_outlined), selectedIcon: Icon(Icons.wb_twilight), label: 'Panchang'),
          ],
        ),
      ),
    );
  }

  Widget _page(BuildContext context, KundliChart c) {
    switch (_nav) {
      case 0:
        return _chartTab(context, c);
      case 1:
        return Column(children: [
          _segmented(const ['Positions', 'Ranking', 'Maitri'], _planetsView,
              (i) => setState(() => _planetsView = i)),
          Expanded(
            child: switch (_planetsView) {
              0 => _planetsTab(c),
              1 => RankingTab(chart: c),
              _ => _maitriTab(context, c),
            },
          ),
        ]);
      case 2:
        return Column(children: [
          _segmented(const ['Shadbala', 'Bhava', 'Ashtaka', 'Vargas'], _strengthView,
              (i) => setState(() => _strengthView = i)),
          Expanded(
            child: switch (_strengthView) {
              0 => _shadbalaTab(context, c),
              1 => _bhavaBalaTab(context, c),
              2 => _ashtakavargaTab(context, c),
              _ => _shodashvargaTab(context, c),
            },
          ),
        ]);
      case 3:
        return Column(children: [
          _segmented(const ['Vimshottari', 'Chara'], _dashaView,
              (i) => setState(() => _dashaView = i)),
          Expanded(
            child: _dashaView == 0
                ? DashaTab(chart: c)
                : CharaDashaTab(chart: c),
          ),
        ]);
      default:
        return _panchangTab(c);
    }
  }

  // ---------------------------------------------------------------- transit
  void _stepTransit({int years = 0, int months = 0, int days = 0}) {
    final t = _transit.toLocal();
    var y = t.year + years, mo = t.month + months;
    y += (mo - 1) ~/ 12;
    mo = (mo - 1) % 12 + 1;
    final dim = DateTime(y, mo + 1, 0).day;
    final moved = DateTime(y, mo, t.day > dim ? dim : t.day, t.hour, t.minute)
        .add(Duration(days: days));
    if (moved.year < 1800 || moved.year > 2399) return;
    setState(() => _transit = moved.toUtc());
  }

  Future<void> _pickTransitDate() async {
    final t = _transit.toLocal();
    final d = await showDatePicker(
      context: context,
      initialDate: t,
      firstDate: DateTime(1800),
      lastDate: DateTime(2399, 12, 31),
    );
    if (d != null) setState(() => _transit = DateTime(d.year, d.month, d.day, t.hour, t.minute).toUtc());
  }

  Future<void> _pickTransitTime() async {
    final t = _transit.toLocal();
    final tod = await showTimePicker(
        context: context, initialTime: TimeOfDay(hour: t.hour, minute: t.minute));
    if (tod != null) {
      setState(() => _transit = DateTime(t.year, t.month, t.day, tod.hour, tod.minute).toUtc());
    }
  }

  Future<void> _useMyLocation({bool quiet = false}) async {
    setState(() => _locating = true);
    String? err;
    try {
      final p = await deviceLocation();
      if (mounted) {
        setState(() {
          _here = p;
          _hereName = null;
        });
      }
    } catch (e) {
      err = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    setState(() => _locating = false);
    if (err != null && !quiet) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  /// Offline fallback: pick the place from the built-in atlas.
  Future<void> _pickCity() async {
    final city = await showDialog<City>(
      context: context,
      builder: (ctx) {
        var results = CityDb.search('', limit: 15);
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: const Text('Where are you now?'),
            content: SizedBox(
              width: double.maxFinite,
              height: 360,
              child: Column(children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Search city', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setD(() => results = CityDb.search(v, limit: 15)),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(children: [
                    for (final c in results)
                      ListTile(dense: true, title: Text(c.name), onTap: () => Navigator.pop(ctx, c)),
                  ]),
                ),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
          ),
        );
      },
    );
    if (city != null && mounted) {
      setState(() {
        _here = (lat: city.lat, lon: city.lon);
        _hereName = city.name;
      });
    }
  }

  String _transitLagnaText() {
    final a = EphemerisEngine.transit(_transit, 0, lat: _here!.lat, lon: _here!.lon)['Asc'];
    return a == null ? '' : 'Transit lagna: ${a.sign} ${_dms(a.degreeInSign)}';
  }

  /// Date and time of the transit, with quick steps (year / month / day).
  Widget _transitBar(BuildContext context) {
    final t = _transit.toLocal();
    Widget step(String label, VoidCallback f) => TextButton(
          style: TextButton.styleFrom(
              minimumSize: const Size(44, 32), padding: const EdgeInsets.symmetric(horizontal: 6)),
          onPressed: f,
          child: Text(label),
        );
    return Column(children: [
      Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.event, size: 18),
          label: Text('Transit: ${DateFormat('dd MMM yyyy').format(t)}'),
          onPressed: _pickTransitDate,
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.schedule, size: 18),
          label: Text(DateFormat('HH:mm').format(t)),
          onPressed: _pickTransitTime,
        ),
        TextButton(
          onPressed: () => setState(() => _transit = DateTime.now().toUtc()),
          child: const Text('Now'),
        ),
        ActionChip(
          avatar: _locating
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_here == null ? Icons.my_location : Icons.location_on, size: 18),
          label: Text(_here == null
              ? 'Use my location'
              : _hereName ?? 'At ${_here!.lat.toStringAsFixed(2)}, ${_here!.lon.toStringAsFixed(2)}'),
          onPressed: _locating ? null : _useMyLocation,
        ),
        ActionChip(
          avatar: const Icon(Icons.location_city, size: 18),
          label: const Text('Choose city'),
          onPressed: _pickCity,
        ),
        if (_here != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove location (no transit ascendant)',
            onPressed: () => setState(() => _here = null),
          ),
      ]),
      if (_here != null)
        Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8, children: [
          FilterChip(
            label: const Text('Draw from transit lagna'),
            selected: _trFromHere,
            onSelected: (v) => setState(() => _trFromHere = v),
          ),
          Text(
            _transitLagnaText(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ]),
      Wrap(alignment: WrapAlignment.center, children: [
        step('−1y', () => _stepTransit(years: -1)),
        step('−1m', () => _stepTransit(months: -1)),
        step('−1w', () => _stepTransit(days: -7)),
        step('−1d', () => _stepTransit(days: -1)),
        step('+1d', () => _stepTransit(days: 1)),
        step('+1w', () => _stepTransit(days: 7)),
        step('+1m', () => _stepTransit(months: 1)),
        step('+1y', () => _stepTransit(years: 1)),
      ]),
    ]);
  }

  Widget _segmented(List<String> labels, int selected, ValueChanged<int> onChanged) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [for (var i = 0; i < labels.length; i++) ButtonSegment(value: i, label: Text(labels[i]))],
            selected: {selected},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ),
      );

  // -------------------------------------------------------------------- BTR
  /// Birth time rectification: shift the birth time and watch lagna, Moon
  /// nakshatra and the dasha at birth change. Save keeps the shifted time.
  Widget _btrBar(BuildContext context, KundliChart c) {
    final scheme = Theme.of(context).colorScheme;
    final run = runningDasha(c.vimshottari, c.birth.wall, levels: 3);
    final moon = c.planets['Moon']!;
    final sign = _delta.isNegative ? '−' : '+';
    final ad = _delta.abs();
    final deltaText = _delta == Duration.zero
        ? 'original time'
        : '$sign${ad.inHours}h ${ad.inMinutes % 60}m ${ad.inSeconds % 60}s';
    Widget btn(String label, Duration d) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _shift(d),
              child: Text(label),
            ),
          ),
        );
    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(children: [
        Row(children: [
          btn('−1h', const Duration(hours: -1)),
          btn('−1m', const Duration(minutes: -1)),
          btn('−1s', const Duration(seconds: -1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(DateFormat('HH:mm:ss').format(c.birth.wall),
                style: Theme.of(context).textTheme.titleMedium),
          ),
          btn('+1s', const Duration(seconds: 1)),
          btn('+1m', const Duration(minutes: 1)),
          btn('+1h', const Duration(hours: 1)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Text(
              '$deltaText  •  Asc ${kSigns[c.lagnaSign]} ${_dms(c.lagnaDegree)}  •  '
              'Moon ${moon.nakshatra}-${moon.pada}  •  '
              'Dasha ${run.map((p) => p.lord).join('-')}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _delta == Duration.zero
                ? null
                : () {
                    _delta = Duration.zero;
                    _recompute();
                  },
            child: const Text('Reset'),
          ),
        ]),
      ]),
    );
  }

  // ------------------------------------------------------------------ chart
  static final Map<int, String> _chartNames = {
    ...kVargaNames,
    100: 'Transit',
    0: 'Sudarshan',
  };

  /// One chart (D1 / varga / transit / Sudarshan). [compact] = small preview.
  Widget _chartOf(BuildContext context, KundliChart c, int key, {required bool compact}) {
    final scheme = Theme.of(context).colorScheme;
    if (key == 0) return SudarshanView(chart: c, instant: _transit, rot: _rot);
    final isTr = key == 100;
    final varga = isTr ? null : c.vargas[key]!;
    final tr = isTr
        ? EphemerisEngine.transit(_transit, c.lagnaSign, lat: _here?.lat, lon: _here?.lon)
        : null;
    final trAsc = tr?['Asc'];
    final fromTransitLagna = isTr && _trFromHere && trAsc != null;
    final chartLagna = fromTransitLagna ? trAsc!.signIndex : (varga?.lagnaSign ?? c.lagnaSign);
    final base = (chartLagna + _rot) % 12;
    final ascDeg =
        fromTransitLagna ? trAsc!.degreeInSign : (varga?.lagnaDegree ?? c.lagnaDegree);
    final opts = LabelOptions(nakshatra: _showNak, lord: _showLord);
    if (fromTransitLagna) tr!.remove('Asc'); // already drawn as the chart's Asc
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: NorthIndianPainter(
          lagnaSign: base,
          ascHouse: (chartLagna - base) % 12 + 1,
          ascLabel: compact ? 'Asc' : 'Asc ${ascDeg.floor()}°',
          labelsByHouse: isTr
              ? buildTransitLabels(tr!, base, opts, compact)
              : buildHouseLabels(c, varga!, base, opts, compact),
          lineColor: scheme.primary,
          textColor: scheme.onSurface,
          fontScale: compact ? 1.45 : 1,
        ),
      ),
    );
  }

  /// Full-size view of a small chart.
  void _openFull(BuildContext context, KundliChart c, int key) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_chartNames[key]!, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            _chartOf(ctx, c, key, compact: false),
          ]),
        ),
      ),
    );
  }

  Widget _smallChart(BuildContext context, KundliChart c, int key, ValueChanged<int> onPick) {
    return Expanded(
      child: Column(children: [
        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: key,
            isDense: true,
            isExpanded: true,
            items: [
              for (final e in _chartNames.entries)
                if (e.key != 1) DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) onPick(v);
            },
          ),
        ),
        GestureDetector(
          onTap: () => _openFull(context, c, key),
          child: _chartOf(context, c, key, compact: true),
        ),
      ]),
    );
  }

  Widget _chartTab(BuildContext context, KundliChart c) {
    final theme = Theme.of(context);
    final needsTransit = _second == 100 || _third == 100 || _second == 0 || _third == 0;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
      Text('D1 Rasi', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: (MediaQuery.of(context).size.width * 0.66).clamp(200.0, 300.0)),
          child: _chartOf(context, c, 1, compact: false),
        ),
      ),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _smallChart(context, c, _second, (v) => setState(() => _second = v)),
        const SizedBox(width: 12),
        _smallChart(context, c, _third, (v) => setState(() => _third = v)),
      ]),
      Text('Tap a small chart to enlarge it.',
          textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
      // ---- rotate (applies to all three charts)
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: const Icon(Icons.rotate_left),
          tooltip: 'Rotate back one house',
          onPressed: () => setState(() => _rot = (_rot + 11) % 12),
        ),
        Text(_rot == 0 ? 'Rotate charts' : 'House ${_rot + 1} shown as 1st'),
        IconButton(
          icon: const Icon(Icons.rotate_right),
          tooltip: 'Rotate forward one house',
          onPressed: () => setState(() => _rot = (_rot + 1) % 12),
        ),
        TextButton(
          onPressed: () => setState(() => _rot = (c.planets['Moon']!.signIndex - c.lagnaSign) % 12),
          child: const Text('From Moon'),
        ),
        if (_rot != 0)
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset rotation',
            onPressed: () => setState(() => _rot = 0),
          ),
      ]),
      if (needsTransit) _transitBar(context),
      Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
        FilterChip(
          label: const Text('Nakshatra-pada'),
          selected: _showNak,
          onSelected: (v) => setState(() => _showNak = v),
        ),
        FilterChip(
          label: const Text('Nakshatra lord'),
          selected: _showLord,
          onSelected: (v) => setState(() => _showLord = v),
        ),
      ]),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
        for (final n in kPlanetOrder)
          ActionChip(
            label: Text(kPlanetShort[n]!),
            onPressed: () => showPlanetSheet(context, c, n),
          ),
      ]),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'ᴿ retrograde, ᶜ combust. Tap a planet for aspects, avastha, karaka and dominance. '
          'Transit / Sudarshan use the birth lagna as house 1.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          title: Text('Lagna: ${kSigns[c.lagnaSign]} ${_dms(c.lagnaDegree)}'),
          subtitle: Text(
              '${kNakshatras[c.lagnaNakshatraIndex]} pada ${c.lagnaPada} (${c.lagnaNakshatraLord})  •  '
              'Ayanamsa (Lahiri): ${_dms(c.ayanamsa)}'),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
        child: Text('Vimshottari dasha', style: theme.textTheme.titleMedium),
      ),
      DashaTab(chart: c, embedded: true),
    ]);
  }

  // ---------------------------------------------------------------- planets
  Widget _planetsTab(KundliChart c) {
    final d9 = c.vargas[9]!;
    final rows = <DataRow>[
      DataRow(cells: [
        const DataCell(Text('Lagna')),
        DataCell(Text(kSigns[c.lagnaSign])),
        DataCell(Text(_dms(c.lagnaDegree))),
        DataCell(Text('${kNakshatras[c.lagnaNakshatraIndex]}-${c.lagnaPada}')),
        DataCell(Text(c.lagnaNakshatraLord)),
        const DataCell(Text('1')),
        DataCell(Text(kSigns[d9.lagnaSign])),
      ]),
      for (final name in kChartBodies)
        if (c.planets[name] != null)
          DataRow(
              onSelectChanged:
                  kUpagrahas.contains(name) ? null : (_) => showPlanetSheet(context, c, name),
              cells: [
            DataCell(Text('$name${planetMarks(c, name)}')),
            DataCell(Text(c.planets[name]!.sign)),
            DataCell(Text(_dms(c.planets[name]!.degreeInSign))),
            DataCell(Text('${c.planets[name]!.nakshatra}-${c.planets[name]!.pada}')),
            DataCell(Text(c.planets[name]!.nakshatraLord)),
            DataCell(Text('${c.planets[name]!.house}')),
            DataCell(Text(kSigns[d9.signs[name]!])),
          ]),
    ];
    return _scroll2D(DataTable(
      showCheckboxColumn: false,
      columnSpacing: 18,
      columns: const [
        DataColumn(label: Text('Planet')),
        DataColumn(label: Text('Sign')),
        DataColumn(label: Text('Degree')),
        DataColumn(label: Text('Nakshatra-Pada')),
        DataColumn(label: Text('Nak. lord')),
        DataColumn(label: Text('House')),
        DataColumn(label: Text('Navamsa')),
      ],
      rows: rows,
    ));
  }

  // --------------------------------------------------------------- panchang
  Widget _panchangTab(KundliChart c) {
    final p = c.panchang;
    Widget row(String k, String v) =>
        ListTile(dense: true, title: Text(k), trailing: Text(v));
    return ListView(children: [
      row('Vara (weekday)', p.vara),
      row('Tithi', '${p.paksha} ${p.tithi} (${p.tithiNumber})'),
      row('Nakshatra', p.nakshatra),
      row('Yoga', p.yoga),
      row('Karana', p.karana),
      row('Sunrise', clockText(p.sunrise)),
      row('Sunset', clockText(p.sunset)),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Vara follows the Vedic day (changes at sunrise). Sunrise/sunset are '
          'computed for the birth place (no atmospheric refraction corrections beyond the standard).',
          style: TextStyle(fontSize: 12),
        ),
      ),
    ]);
  }

  // ------------------------------------------------------------ ashtakavarga
  Widget _shodashvargaTab(BuildContext context, KundliChart c) {
    final vim = computeVimshopaka(c.vargas, c.relations);
    final scheme = Theme.of(context).colorScheme;
    String sign(VargaChart v, String? p) =>
        kSignsShort[p == null ? v.lagnaSign : v.signs[p]!];
    final table = DataTable(
      columnSpacing: 10,
      headingRowHeight: 40,
      dataRowMinHeight: 34,
      dataRowMaxHeight: 38,
      columns: [
        const DataColumn(label: Text('')),
        for (final n in kShownVargas) DataColumn(label: Text('D$n')),
      ],
      rows: [
        for (final p in <String?>[null, ...kChartBodies])
          DataRow(cells: [
            DataCell(Text(p == null ? 'Asc' : kPlanetShort[p]!,
                style: const TextStyle(fontWeight: FontWeight.bold))),
            for (final n in kShownVargas) DataCell(Text(sign(c.vargas[n]!, p))),
          ]),
      ],
    );
    final vimTable = DataTable(
      columnSpacing: 14,
      headingRowHeight: 40,
      dataRowMinHeight: 34,
      dataRowMaxHeight: 38,
      columns: const [
        DataColumn(label: Text('Planet')),
        DataColumn(label: Text('Vimshopaka /20'), numeric: true),
        DataColumn(label: Text('Grade')),
      ],
      rows: [
        for (final p in kSeven)
          DataRow(cells: [
            DataCell(Text(p)),
            DataCell(Text(vim.total[p]!.toStringAsFixed(2))),
            DataCell(Text(Vimshopaka.grade(vim.total[p]!))),
          ]),
      ],
    );
    return ListView(padding: const EdgeInsets.all(8), children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Shodashvarga — sign of the ascendant and each planet in the 16 divisions.',
            style: Theme.of(context).textTheme.titleSmall),
      ),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: table),
      const Divider(height: 24),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Vimshopaka bala (Shodasavarga)',
            style: Theme.of(context).textTheme.titleSmall),
      ),
      vimTable,
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Weights: D1 3.5, D9 3, D16 2, D60 4, D2 / D3 / D30 1, the rest 0.5 (total 20). '
          'Each varga scores 20 for own / exalted sign, else 18 / 15 / 10 / 7 / 5 by '
          'adhi-mitra / mitra / sama / shatru / adhi-shatru relation with the sign lord. '
          'Grades: ≥18 Poorna, ≥15 Atyuttama, ≥12 Uttama, ≥10 Madhyama, else Kanishtha. '
          'This is the app\'s own implementation; schools differ in the details.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
      ),
    ]);
  }

  Widget _ashtakavargaTab(BuildContext context, KundliChart c) {
    final av = c.ashtakavarga;
    return _scroll2D(DataTable(
      columnSpacing: 12,
      headingRowHeight: 40,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 40,
      columns: [
        const DataColumn(label: Text('')),
        for (final s in kSignsShort) DataColumn(label: Text(s), numeric: true),
        const DataColumn(label: Text('Total'), numeric: true),
      ],
      rows: [
        for (final p in kSeven)
          DataRow(cells: [
            DataCell(Text(kPlanetShort[p]!)),
            for (var i = 0; i < 12; i++) DataCell(Text('${av.bav[p]![i]}')),
            DataCell(Text('${av.total(p)}')),
          ]),
        DataRow(
          color: WidgetStatePropertyAll(
              Theme.of(context).colorScheme.primaryContainer),
          cells: [
            const DataCell(Text('SAV', style: TextStyle(fontWeight: FontWeight.bold))),
            for (var i = 0; i < 12; i++)
              DataCell(Text('${av.sav[i]}',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text('${av.sav.fold(0, (a, b) => a + b)}',
                style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      ],
    ));
  }

  // --------------------------------------------------------------- shadbala
  Widget _shadbalaTab(BuildContext context, KundliChart c) {
    final sb = c.shadbala;
    final scheme = Theme.of(context).colorScheme;
    String v(double x) => x.toStringAsFixed(1);
    return ListView(padding: const EdgeInsets.all(8), children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Text('Values in virupas (60 virupas = 1 rupa). The mark on each bar is the '
            'optimum (required minimum); a planet is strong when it reaches 100%.',
            style: TextStyle(fontSize: 12)),
      ),
      _weakSummary(context, sb),
      for (final name in kSeven)
        Builder(builder: (_) {
          final s = sb.planets[name]!;
          return ExpansionTile(
            leading: Icon(s.strong ? Icons.trending_up : Icons.trending_down,
                color: s.strong ? Colors.green : scheme.error),
            title: Text('$name  ${s.rupas.toStringAsFixed(2)} rupa'),
            subtitle: _OptimumBar(
                value: s.total,
                optimum: s.required,
                label: '${v(s.total)} / ${s.required.toStringAsFixed(0)} virupas'),
            children: [
              _kv('Sthana bala', v(s.sthana), bold: true),
              _kv('   Uccha', v(s.uccha)),
              _kv('   Saptavargaja', v(s.saptavargaja)),
              _kv('   Ojhayugma', v(s.ojhayugma)),
              _kv('   Kendradi', v(s.kendradi)),
              _kv('   Drekkana', v(s.drekkana)),
              _kv('Dig bala', v(s.dig), bold: true),
              _kv('Kala bala', v(s.kala), bold: true),
              _kv('   Nathonnata', v(s.nathonnata)),
              _kv('   Paksha', v(s.paksha)),
              _kv('   Tribhaga', v(s.tribhaga)),
              _kv('   Abda / Masa', '${v(s.abda)} / ${v(s.masa)}'),
              _kv('   Vara / Hora', '${v(s.vara)} / ${v(s.hora)}'),
              _kv('   Ayana', v(s.ayana)),
              _kv('Cheshta bala', v(s.cheshta), bold: true),
              _kv('Naisargika bala', v(s.naisargika), bold: true),
              _kv('Drik bala', v(s.drik), bold: true),
            ],
          );
        }),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Lords at birth: Vara ${sb.varaLord}, Hora ${sb.horaLord}, '
          'Tribhaga ${sb.tribhagaLord}, Abda ${sb.abdaLord}, Masa ${sb.masaLord}.\n'
          'Method: B.V. Raman / V.P. Jain (checked against the books\' worked examples). '
          'Yuddha bala is not included; Sun/Moon have no Cheshta bala; Cheshta bala may '
          'differ by a few virupas from software using Surya-Siddhanta mean tables.',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ]);
  }

  // ----------------------------------------------------------------- maitri
  Widget _maitriTab(BuildContext context, KundliChart c) {
    final scheme = Theme.of(context).colorScheme;
    Color colorOf(int v) => switch (v) {
          2 => Colors.green.shade700,
          1 => Colors.green,
          0 => Colors.grey,
          -1 => Colors.orange.shade800,
          _ => scheme.error,
        };
    String short(int v) => switch (v) { 2 => 'AM', 1 => 'M', 0 => 'S', -1 => 'E', _ => 'AE' };
    Widget table(String title, int Function(Relation) pick, {String? note}) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        if (note != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(note, style: const TextStyle(fontSize: 12))),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 36,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 36,
            columns: [
              const DataColumn(label: Text('')),
              for (final q in kSeven) DataColumn(label: Text(kPlanetShort[q]!)),
            ],
            rows: [
              for (final p in kSeven)
                DataRow(cells: [
                  DataCell(Text(kPlanetShort[p]!, style: const TextStyle(fontWeight: FontWeight.bold))),
                  for (final q in kSeven)
                    DataCell(p == q
                        ? const Text('–')
                        : Text(short(pick(c.relations.of(p, q))),
                            style: TextStyle(color: colorOf(pick(c.relations.of(p, q))), fontWeight: FontWeight.w600))),
                ]),
            ],
          ),
        ),
      ]);
    }

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: Text('Row planet\'s attitude towards the column planet.  '
            'AM = adhi-mitra (great friend), M = mitra (friend), S = sama (neutral), '
            'E = shatru (enemy), AE = adhi-shatru (great enemy).',
            style: TextStyle(fontSize: 12)),
      ),
      table('Natural friendship (Naisargika)', (r) => r.natural),
      table('Temporal friendship (Tatkalika)', (r) => r.temporal,
          note: 'Friend if the other planet is in the 2nd, 3rd, 4th, 10th, 11th or 12th sign from it; otherwise enemy.'),
      table('Compound friendship (Panchadha)', (r) => r.compound,
          note: 'Natural + temporal, used for dignity in Shadbala.'),
    ]);
  }

  // ------------------------------------------------------------- bhava bala
  Widget _bhavaBalaTab(BuildContext context, KundliChart c) {
    return ListView(padding: const EdgeInsets.all(8), children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Text('Bhava bala = Bhavadhipati (lord\'s Shadbala) + Bhava dig + Bhava drishti, '
            'in virupas (60 = 1 rupa). The mark shows the optimum of 7 rupas (420 virupas). '
            'Houses are measured from the ascendant degree (equal-house madhya).',
            style: TextStyle(fontSize: 12)),
      ),
      for (final b in c.bhavaBala)
        Builder(builder: (_) {
          return ExpansionTile(
            title: Text('House ${b.house} • ${kSigns[b.sign]} (${b.lord})'),
            subtitle: _OptimumBar(value: b.total, optimum: kMinBhavaBala, label:
                '${b.rupas.toStringAsFixed(2)} rupa'),
            children: [
              _kv('Bhavadhipati (lord ${b.lord})', b.adhipati.toStringAsFixed(1)),
              _kv('Bhava dig bala (${b.signClass.name})', b.dig.toStringAsFixed(1)),
              _kv('Bhava drishti bala', b.drishti.toStringAsFixed(1)),
              _kv('Total', b.total.toStringAsFixed(1), bold: true),
            ],
          );
        }),
    ]);
  }

  // ---------------------------------------------------------------- helpers
  Widget _weakSummary(BuildContext context, ShadbalaResult sb) {
    final weak = [for (final p in kSeven) if (!sb.planets[p]!.strong) p];
    final scheme = Theme.of(context).colorScheme;
    if (weak.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.check_circle, color: Colors.green),
          title: Text('All seven planets reach their optimum Shadbala.'),
        ),
      );
    }
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Below optimum', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final p in weak)
            Text('• $p: ${(sb.planets[p]!.ratio * 100).toStringAsFixed(0)}% of optimum '
                '(short by ${((1 - sb.planets[p]!.ratio) * 100).toStringAsFixed(0)}%, '
                '${(sb.planets[p]!.required - sb.planets[p]!.total).toStringAsFixed(0)} virupas)'),
        ]),
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) => ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        title: Text(k, style: TextStyle(fontWeight: bold ? FontWeight.w600 : null)),
        trailing: Text(v),
      );

  Widget _scroll2D(Widget child) => SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: child),
      );

  String _dms(double deg) {
    final total = (deg * 3600).floor(); // truncate, never round up into the next minute/degree
    final d = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    return '$d°${m.toString().padLeft(2, '0')}\'${s.toString().padLeft(2, '0')}"';
  }
}

/// Progress bar with a mark at the optimum (100%). Green at or above the
/// optimum, red below it, with the percentage written out.
class _OptimumBar extends StatelessWidget {
  final double value;
  final double optimum;
  final String label;
  const _OptimumBar({required this.value, required this.optimum, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = value / optimum * 100;
    final ok = value >= optimum;
    final color = ok ? Colors.green : scheme.error;
    const scaleMax = 1.5; // bar spans 0 - 150% of optimum
    final fill = (value / optimum / scaleMax).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label  •  ${pct.toStringAsFixed(0)}% of optimum'
          '${ok ? '' : '  (−${(100 - pct).toStringAsFixed(0)}%)'}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      SizedBox(
        height: 12,
        child: LayoutBuilder(builder: (context, box) {
          final markX = box.maxWidth / scaleMax;
          return Stack(clipBehavior: Clip.none, children: [
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            FractionallySizedBox(
              widthFactor: fill,
              child: Container(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
              ),
            ),
            Positioned(
              left: markX - 1,
              top: -3,
              bottom: -3,
              child: Container(width: 2, color: scheme.onSurface),
            ),
          ]);
        }),
      ),
      const SizedBox(height: 2),
      Text('optimum = 100% (mark)', style: const TextStyle(fontSize: 10)),
    ]);
  }
}
