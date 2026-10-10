import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../access.dart';
import '../config.dart';

/// Shown when the paid access is missing or over (full screen, cannot be skipped),
/// and from the Home menu to check validity / add more time ([embedded] = true).
class RechargeScreen extends StatefulWidget {
  final VoidCallback? onActivated;
  final bool embedded;
  const RechargeScreen({super.key, this.onActivated, this.embedded = false});

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  final _code = TextEditingController();
  DateTime? _expiry;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final e = await Access.expiry();
    if (mounted) setState(() => _expiry = e);
  }

  Future<void> _openRecharge() async {
    final ok = await launchUrl(Uri.parse(kRechargeUrl), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _message = 'Could not open the browser. Visit $kRechargeUrl');
    }
  }

  Future<void> _paste() async {
    final t = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (t.isNotEmpty) setState(() => _code.text = t.trim());
  }

  Future<void> _activate() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final r = await Access.activate(_code.text);
    if (!mounted) return;
    await _load();
    setState(() {
      _busy = false;
      _message = switch (r) {
        ActivateResult.ok => 'Recharge successful. Thank you!',
        ActivateResult.invalid => 'This code is not valid. Check it and try again.',
        ActivateResult.used => 'This code was already used on this phone.',
        ActivateResult.tooOld => 'This code is too old to activate. Please contact support.',
        ActivateResult.noSecret => 'This build cannot check codes. Please install the official app.',
      };
    });
    if (r == ActivateResult.ok) {
      _code.clear();
      widget.onActivated?.call();
      if (widget.embedded && mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd MMM yyyy, HH:mm');
    final active = _expiry != null && _expiry!.isAfter(DateTime.now());
    final status = _expiry == null
        ? 'Recharge is required to use the app.'
        : active
            ? 'Your plan is active until ${df.format(_expiry!)}.'
            : 'Your plan ended on ${df.format(_expiry!)}. Please recharge to continue.';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.embedded ? 'Recharge / validity' : 'AstroWizard Kundali Software'),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (!widget.embedded) ...[
            const SizedBox(height: 12),
            Icon(Icons.lock_outline, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Recharge required',
                textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          ],
          const SizedBox(height: 8),
          Text(status, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Recharge now'),
            onPressed: _openRecharge,
          ),
          const SizedBox(height: 6),
          Text('You will get an activation code after the payment.',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const Divider(height: 40),
          Text('Already have a code?', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'XXXXX-XXXXX-XXXXX-XXXXX',
              suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste), tooltip: 'Paste', onPressed: _paste),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _busy ? null : _activate,
            child: Text(_busy ? 'Checking...' : 'Activate'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_message!, textAlign: TextAlign.center),
            ),
        ]),
      ),
    );
  }
}
