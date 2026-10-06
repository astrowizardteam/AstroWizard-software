import 'package:flutter/material.dart';

/// A list of sibling periods where one can be open at a time. Every tile gets
/// ▲ / ▼ buttons that jump to the previous / next period of the same level.
class SiblingList extends StatefulWidget {
  final int count;
  final int? initialOpen;
  final Widget Function(
    BuildContext context,
    int index,
    bool open,
    VoidCallback toggle,
    VoidCallback? prev,
    VoidCallback? next,
  ) itemBuilder;

  const SiblingList({
    super.key,
    required this.count,
    required this.itemBuilder,
    this.initialOpen,
  });

  @override
  State<SiblingList> createState() => _SiblingListState();
}

class _SiblingListState extends State<SiblingList> {
  late int? _open = widget.initialOpen;
  late final List<GlobalKey> _keys = List.generate(widget.count, (_) => GlobalKey());

  void _go(int j) {
    setState(() => _open = j);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[j].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            alignment: 0.05, duration: const Duration(milliseconds: 250));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < widget.count; i++)
        KeyedSubtree(
          key: _keys[i],
          child: widget.itemBuilder(
            context,
            i,
            _open == i,
            () => setState(() => _open = _open == i ? null : i),
            i > 0 ? () => _go(i - 1) : null,
            i < widget.count - 1 ? () => _go(i + 1) : null,
          ),
        ),
    ]);
  }
}

/// One dasha row: ◀ contract, ▶ expand, ▲ previous period, ▼ next period.
class PeriodTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool current;
  final bool open;
  final bool expandable;
  final VoidCallback onToggle;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final double indent;
  final List<Widget> children;

  const PeriodTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.current,
    required this.open,
    required this.expandable,
    required this.onToggle,
    required this.onPrev,
    required this.onNext,
    required this.indent,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget btn(IconData icon, VoidCallback? f, String tip) => IconButton(
          icon: Icon(icon, size: 20),
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: f,
        );
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Column(children: [
        ListTile(
          dense: true,
          onTap: expandable ? onToggle : null,
          title: Text(title,
              style: TextStyle(
                fontWeight: current ? FontWeight.bold : FontWeight.normal,
                color: current ? scheme.primary : null,
              )),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            btn(Icons.keyboard_arrow_left, expandable && open ? onToggle : null, 'Contract'),
            btn(Icons.keyboard_arrow_right, expandable && !open ? onToggle : null, 'Expand'),
            btn(Icons.keyboard_arrow_up, onPrev, 'Previous period'),
            btn(Icons.keyboard_arrow_down, onNext, 'Next period'),
          ]),
        ),
        if (open) ...children,
      ]),
    );
  }
}
