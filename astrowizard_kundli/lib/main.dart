import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'brand.dart';
import 'config.dart';
import 'engine/cities.dart';
import 'engine/ephemeris.dart';
import 'engine/models.dart';
import 'storage.dart';
import 'transfer.dart';
import 'access.dart';
import 'ui/guide_screen.dart';
import 'ui/recharge_screen.dart';
import 'xml_io.dart';
import 'ui/chart_screen.dart';
import 'ui/input_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Show errors on screen instead of a blank white page.
  ErrorWidget.builder = (details) => Material(
        color: Colors.white,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              'Something went wrong:\n\n${details.exceptionAsString()}\n\n${details.stack}',
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
        ),
      );
  String? startupError;
  try {
    await EphemerisEngine.init();
  } catch (e, st) {
    startupError = 'Ephemeris could not start:\n\n$e\n\n$st';
  }
  await CityDb.load();
  runApp(startupError == null
      ? const AstroWizardApp()
      : MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(startupError, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ));
}

/// Quiet, flat theme: one accent colour, no elevation, thin outlines.
ThemeData _theme(Brightness brightness) {
  final scheme = brandScheme(brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
          fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.w700, color: scheme.primary),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: scheme.secondaryContainer,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
  );
}

/// Lets the app open only while the paid access is active (checked offline).
class AccessGate extends StatefulWidget {
  const AccessGate({super.key});

  @override
  State<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends State<AccessGate> with WidgetsBindingObserver {
  bool? _active;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check(sync: true);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(sync: true);
  }

  bool _synced = false;

  Future<void> _check({bool sync = false}) async {
    var a = await Access.isActive();
    // Ask the server when locked (also restores access after "clear data") and,
    // once per app start, when active (picks up an extended plan).
    if (sync && (!a || !_synced)) {
      await Access.sync();
      _synced = true;
      a = await Access.isActive();
    }
    if (mounted && a != _active) setState(() => _active = a);
  }

  @override
  Widget build(BuildContext context) {
    if (_active == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _active! ? const HomeScreen() : RechargeScreen(onActivated: _check);
  }
}

class AstroWizardApp extends StatelessWidget {
  const AstroWizardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AstroWizard Kundali Software',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const AccessGate(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SavedChart> _saved = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await ChartStore.load();
    if (mounted) setState(() {
      _saved = list;
      _loaded = true;
    });
  }

  Future<void> _open(BirthData b, {String? id}) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => ChartScreen(birth: b, savedId: id)));
    _reload();
  }

  /// A new chart opens unsaved; the Save button in the chart screen stores it.
  Future<void> _create() async {
    final b = await Navigator.push<BirthData>(
        context, MaterialPageRoute(builder: (_) => const InputScreen()));
    if (b != null && mounted) await _open(b);
  }

  Future<void> _edit(SavedChart s) async {
    final b = await Navigator.push<BirthData>(
        context, MaterialPageRoute(builder: (_) => InputScreen(initial: s.birth)));
    if (b == null) return;
    await ChartStore.upsert(s.id, b);
    await _reload();
    if (mounted) await _open(b, id: s.id);
  }

  Future<void> _delete(SavedChart s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chart?'),
        content: Text(s.birth.name.isEmpty ? 'This chart will be removed.' : '${s.birth.name} will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ChartStore.delete(s.id);
      _reload();
    }
  }

  Future<void> _exportFile() async {
    if (_saved.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No saved charts to export')));
      return;
    }
    await shareJsonFile(await ChartStore.exportJson(), 'astrowizard_charts');
  }

  Future<void> _exportXml() async {
    if (_saved.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No saved charts to export')));
      return;
    }
    await shareXmlFile(chartsToXml(_saved), 'astrowizard_charts');
  }

  Future<void> _importFile() async {
    String msg;
    try {
      final n = await pickAndImportCharts();
      if (n == null) return;
      msg = '$n charts imported';
      await _reload();
    } on FormatException catch (e) {
      msg = 'Could not import: ${e.message}';
    } catch (_) {
      msg = 'Could not import: not a valid chart file';
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _backup() async {
    final text = await ChartStore.exportJson();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup copied'),
        content: Text('${_saved.length} charts copied to the clipboard. Paste them into '
            'Notes, WhatsApp (Message yourself), email or a file and keep it safe. '
            'Use Restore to bring them back.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _restore() async {
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    final ctrl = TextEditingController(text: clip.contains('"charts"') || clip.trimLeft().startsWith('[') ? clip : '');
    if (!mounted) return;
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore charts'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctrl,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Paste the backup text here',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Restore')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    String msg;
    try {
      final n = await ChartStore.importJson(text);
      msg = '$n charts restored';
      await _reload();
    } on FormatException catch (e) {
      msg = 'Could not restore: ${e.message}';
    } catch (_) {
      msg = 'Could not restore: invalid backup text';
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy, HH:mm:ss');
    return Scaffold(
      appBar: AppBar(
        title: const Text('AstroWizard Kundali Software'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share with a friend',
            onPressed: () => Share.share(kShareMessage, subject: 'AstroWizard Kundali Software'),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'export':
                  _exportFile();
                case 'exportxml':
                  _exportXml();
                case 'import':
                  _importFile();
                case 'recharge':
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RechargeScreen(embedded: true)));
                case 'guide':
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const GuideScreen()));
                case 'backup':
                  _backup();
                default:
                  _restore();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Export all charts (JSON)')),
              PopupMenuItem(value: 'exportxml', child: Text('Export all charts (XML)')),
              PopupMenuItem(value: 'import', child: Text('Import charts (JSON / XML file)')),
              PopupMenuItem(value: 'guide', child: Text('Dasha guide')),
              PopupMenuItem(value: 'recharge', child: Text('Recharge / validity')),
              PopupMenuItem(value: 'backup', child: Text('Backup to clipboard')),
              PopupMenuItem(value: 'restore', child: Text('Restore from pasted text')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New'),
        elevation: 0,
      ),
      body: !_loaded
          ? const SizedBox.shrink()
          : _saved.isEmpty
              ? Center(
                  child: Text('No saved charts yet',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  itemCount: _saved.length,
                  itemBuilder: (_, i) {
                    final s = _saved[i];
                    final b = s.birth;
                    return Card(
                      child: ListTile(
                        title: Text(b.name.isEmpty ? 'Unnamed' : b.name),
                        subtitle: Text('${df.format(b.wall)}\n${b.place}'),
                        isThreeLine: true,
                        onTap: () => _open(b, id: s.id),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            switch (v) {
                              case 'open':
                                _open(b, id: s.id);
                              case 'edit':
                                _edit(s);
                              case 'delete':
                                _delete(s);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'open', child: Text('Open')),
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
