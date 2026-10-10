import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

const _alpha = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// Day 0 of the "issued on" field of a code.
final DateTime kCodeEpoch = DateTime.utc(2024, 1, 1);

/// A code can be activated within this many days after it was issued.
const int kCodeActivationWindowDays = 60;

class ActivationCode {
  final int days; // validity it adds
  final int issueDay; // days since 2024-01-01 UTC
  final int id;
  const ActivationCode(this.days, this.issueDay, this.id);
}

List<int> _mac(String secret, List<int> data) =>
    Hmac(sha256, utf8.encode(secret)).convert(data).bytes;

String _b32(List<int> data) {
  final bits = StringBuffer();
  for (final b in data) {
    bits.write(b.toRadixString(2).padLeft(8, '0'));
  }
  var s = bits.toString();
  while (s.length % 5 != 0) {
    s += '0';
  }
  final out = StringBuffer();
  for (var i = 0; i < s.length; i += 5) {
    out.write(_alpha[int.parse(s.substring(i, i + 5), radix: 2)]);
  }
  return out.toString();
}

/// Builds a code (the WordPress / Python issuers do the same; this is used by tests).
String makeActivationCode(String secret, int days, int issueDay, int id) {
  final payload = <int>[
    days >> 8, days & 255, issueDay >> 8, issueDay & 255,
    (id >> 16) & 255, (id >> 8) & 255, id & 255,
  ];
  final c = _b32([...payload, ..._mac(secret, payload).sublist(0, 5)]);
  return [for (var i = 0; i < 20; i += 5) c.substring(i, i + 5)].join('-');
}

/// Returns the parsed code if [input] is a genuine code for [secret], else null.
ActivationCode? parseActivationCode(String input, String secret) {
  if (secret.isEmpty) return null;
  var t = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
  t = t.replaceAll('O', '0').replaceAll('I', '1').replaceAll('L', '1').replaceAll('U', 'V');
  if (t.length != 20) return null;
  final bits = StringBuffer();
  for (final ch in t.split('')) {
    final v = _alpha.indexOf(ch);
    if (v < 0) return null;
    bits.write(v.toRadixString(2).padLeft(5, '0'));
  }
  final b = bits.toString();
  final bytes = <int>[for (var i = 0; i < 96; i += 8) int.parse(b.substring(i, i + 8), radix: 2)];
  final payload = bytes.sublist(0, 7);
  final mac = _mac(secret, payload).sublist(0, 5);
  var diff = 0;
  for (var i = 0; i < 5; i++) {
    diff |= mac[i] ^ bytes[7 + i];
  }
  if (diff != 0) return null;
  return ActivationCode((payload[0] << 8) | payload[1], (payload[2] << 8) | payload[3],
      (payload[4] << 16) | (payload[5] << 8) | payload[6]);
}

enum ActivateResult { ok, invalid, used, tooOld, noSecret }

/// Paid-access state, kept on the device. Values are signed so they cannot be
/// edited by hand, and the clock can't be wound back to gain time.
class Access {
  static const _kExp = 'aw_access_exp';
  static const _kSeen = 'aw_access_seen';
  static const _kUsed = 'aw_access_used';

  static String _sign(String label, int ms) {
    final m = _mac(kActivationSecret, utf8.encode('$label:$ms')).sublist(0, 8);
    return Uint8List.fromList(m).map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  static int? _read(SharedPreferences p, String key, String label) {
    final raw = p.getString(key);
    if (raw == null || kActivationSecret.isEmpty) return null;
    final parts = raw.split('.');
    if (parts.length != 2) return null;
    final ms = int.tryParse(parts[0]);
    if (ms == null || parts[1] != _sign(label, ms)) return null;
    return ms;
  }

  static Future<void> _write(SharedPreferences p, String key, String label, int ms) =>
      p.setString(key, '$ms.${_sign(label, ms)}');

  /// Current time that never goes backwards, even if the phone clock is changed.
  static DateTime _now(SharedPreferences p) {
    final seen = _read(p, _kSeen, 'seen');
    final now = DateTime.now().millisecondsSinceEpoch;
    return DateTime.fromMillisecondsSinceEpoch(seen != null && seen > now ? seen : now);
  }

  /// When the paid access ends (null = never activated).
  static Future<DateTime?> expiry() async {
    final p = await SharedPreferences.getInstance();
    final e = _read(p, _kExp, 'exp');
    return e == null ? null : DateTime.fromMillisecondsSinceEpoch(e);
  }

  static Future<bool> isActive() async {
    final p = await SharedPreferences.getInstance();
    final now = _now(p);
    await _write(p, _kSeen, 'seen', now.millisecondsSinceEpoch);
    final e = _read(p, _kExp, 'exp');
    return e != null && now.millisecondsSinceEpoch < e;
  }

  static Future<ActivateResult> activate(String input) async {
    if (kActivationSecret.isEmpty) return ActivateResult.noSecret;
    final code = parseActivationCode(input, kActivationSecret);
    if (code == null) return ActivateResult.invalid;
    final p = await SharedPreferences.getInstance();
    final now = _now(p);
    final age = now.toUtc().difference(kCodeEpoch).inDays - code.issueDay;
    if (age > kCodeActivationWindowDays) return ActivateResult.tooOld;
    final used = p.getStringList(_kUsed) ?? [];
    final key = '${code.issueDay}-${code.id}';
    if (used.contains(key)) return ActivateResult.used;
    final cur = _read(p, _kExp, 'exp') ?? 0;
    final base = cur > now.millisecondsSinceEpoch ? cur : now.millisecondsSinceEpoch;
    final end = base + code.days * Duration.millisecondsPerDay;
    await _write(p, _kExp, 'exp', end);
    await _write(p, _kSeen, 'seen', now.millisecondsSinceEpoch);
    await p.setStringList(_kUsed, [...used, key]);
    return ActivateResult.ok;
  }
}
