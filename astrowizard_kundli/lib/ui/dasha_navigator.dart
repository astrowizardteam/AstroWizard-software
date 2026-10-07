import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final DateFormat _day = DateFormat('dd MMM yyyy');
final DateFormat _sec = DateFormat('dd MMM yyyy HH:mm:ss');

String fmtDasha(DateTime t, int level) => level <= 2 ? _day.format(t) : _sec.format(t);

/// One dasha period, independent of the system (Vimshottari / Chara).
class DashaNode {
  final String title;
  final DateTime start, end;
  final int level; // 1..5
  final List<DashaNode> Function() children;
  const DashaNode(this.title, this.start, this.end, this.level, this.children);

  bool isNow(DateTime now) => !now.isBefore(start) && now.isBefore(end);
}

/// Parashara's-Light style dasha browser: one column per level, side by side.
/// ▶ opens the sub-periods of the selected period in a new column on the right,
/// ◀ goes back to the parent column, ▲ / ▼ move to the previous / next period
/// in the active column. Starts on the running period.
class DashaNavigator extends StatefulWidget {
  final List<DashaNode> roots;
  final List<String> levelNames;
  final DateTime now;
  final double height;
  const DashaNavigator({
    super.key,
    required this.roots,
    required this.levelNames,
    required this.now,
    required this.height,
  });

  @override
  State<DashaNavigator> createState() => _DashaNavigatorState();
}

class _DashaNavigatorState extends State<DashaNavigator> {
  static const double _colW = 176;
  static const double _rowH = 66;
  static const int _maxLevel = 5;

  final List<int> _sel = []; // selected index per level (0-based level)
  int _focus = 0;
  final _hScroll = ScrollController();
  final List<ScrollController> _vScroll =
      List.generate(_maxLevel, (_) => ScrollController());
  final Map<String, List<DashaNode>> _cache = {};

  @override
  void initState() {
    super.initState();
    var list = widget.roots;
    while (_sel.length < _maxLevel) {
      final i = list.indexWhere((n) => n.isNow(widget.now));
      if (i < 0) break;
      _sel.add(i);
      if (_sel.length < _maxLevel) list = _childrenOf(_sel.length - 1);
    }
    if (_sel.isEmpty) {
      _focus = 0;
    } else {
      _focus = _sel.length - 1;
    }
    _reveal();
  }

  @override
  void dispose() {
    _hScroll.dispose();
    for (final c in _vScroll) {
      c.dispose();
    }
    super.dispose();
  }

  /// Items shown in column [col].
  List<DashaNode> _column(int col) {
    if (col == 0) return widget.roots;
    return _childrenOf(col - 1);
  }

  /// Children of the node selected in column [col].
  List<DashaNode> _childrenOf(int col) {
    final key = _sel.sublist(0, col + 1).join('.');
    return _cache.putIfAbsent(key, () {
      final node = _column(col)[_sel[col]];
      return node.level >= _maxLevel ? const <DashaNode>[] : node.children();
    });
  }

  int get _cols => _sel.length >= _maxLevel ? _maxLevel : _sel.length + 1;

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_hScroll.hasClients) {
        final target = (_focus * _colW - 8).clamp(0.0, _hScroll.position.maxScrollExtent);
        _hScroll.animateTo(target,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
      for (var c = 0; c < _sel.length; c++) {
        final sc = _vScroll[c];
        if (!sc.hasClients) continue;
        final target = (_sel[c] * _rowH - _rowH).clamp(0.0, sc.position.maxScrollExtent);
        sc.animateTo(target,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _select(int col, int idx) {
    setState(() {
      if (_sel.length > col) {
        _sel.removeRange(col, _sel.length);
      }
      _sel.add(idx);
      _focus = col;
    });
    _reveal();
  }

  void _right() {
    if (_sel.length <= _focus) return; // nothing selected here
    if (_focus + 1 >= _maxLevel) return;
    final child = _column(_focus + 1);
    if (child.isEmpty) return;
    setState(() {
      _focus += 1;
      if (_sel.length <= _focus) {
        final cur = child.indexWhere((n) => n.isNow(widget.now));
        _sel.add(cur < 0 ? 0 : cur);
      }
    });
    _reveal();
  }

  void _left() {
    if (_focus == 0) return;
    setState(() => _focus -= 1);
    _reveal();
  }

  void _step(int d) {
    final list = _column(_focus);
    final cur = _sel.length > _focus ? _sel[_focus] : (d > 0 ? -1 : list.length);
    final next = cur + d;
    if (next < 0 || next >= list.length) return;
    _select(_focus, next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fl = _column(_focus);
    final canUp = _sel.length > _focus && _sel[_focus] > 0;
    final canDown = _sel.length <= _focus ? fl.isNotEmpty : _sel[_focus] < fl.length - 1;
    final canRight =
        _sel.length > _focus && _focus + 1 < _maxLevel && _column(_focus + 1).isNotEmpty;
    final path = [
      for (var i = 0; i < _sel.length; i++) _column(i)[_sel[i]].title,
    ].join(' › ');

    Widget btn(IconData icon, VoidCallback? f, String tip) => IconButton.filledTonal(
          icon: Icon(icon),
          tooltip: tip,
          onPressed: f,
        );

    return SizedBox(
      height: widget.height,
      child: Column(children: [
        Row(children: [
          btn(Icons.keyboard_arrow_left, _focus > 0 ? _left : null, 'Back to parent level'),
          const SizedBox(width: 6),
          btn(Icons.keyboard_arrow_right, canRight ? _right : null, 'Show sub-periods'),
          const SizedBox(width: 6),
          btn(Icons.keyboard_arrow_up, canUp ? () => _step(-1) : null, 'Previous period'),
          const SizedBox(width: 6),
          btn(Icons.keyboard_arrow_down, canDown ? () => _step(1) : null, 'Next period'),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              path.isEmpty ? 'Select a period' : path,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: SingleChildScrollView(
            controller: _hScroll,
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var col = 0; col < _cols; col++) _columnView(context, col, scheme),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _columnView(BuildContext context, int col, ColorScheme scheme) {
    final items = _column(col);
    final focused = col == _focus;
    final selected = col < _sel.length ? _sel[col] : -1;
    return Container(
      width: _colW,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        border: Border.all(
            color: focused ? scheme.primary : scheme.outlineVariant, width: focused ? 2 : 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: focused ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Text(
            widget.levelNames[col],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: focused ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _vScroll[col],
            itemExtent: _rowH,
            itemCount: items.length,
            itemBuilder: (_, i) {
              final n = items[i];
              final now = n.isNow(widget.now);
              final sel = i == selected;
              return InkWell(
                onTap: () => _select(col, i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: sel ? scheme.primaryContainer : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(n.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: sel || now ? FontWeight.bold : FontWeight.normal,
                                  color: now ? scheme.primary : null)),
                        ),
                        if (now) Icon(Icons.circle, size: 8, color: scheme.primary),
                      ]),
                      Text(fmtDasha(n.start, n.level), style: const TextStyle(fontSize: 11)),
                      Text('→ ${fmtDasha(n.end, n.level)}',
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
