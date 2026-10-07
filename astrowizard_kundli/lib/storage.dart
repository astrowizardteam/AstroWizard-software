import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'engine/models.dart';

class SavedChart {
  final String id;
  final BirthData birth;
  const SavedChart(this.id, this.birth);
}

/// Rebuilds a wall-clock (UTC-flagged) DateTime from any parsed value, so
/// device time zones never shift a stored birth time.
DateTime _asWall(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day, t.hour, t.minute, t.second);

/// Saved charts in SharedPreferences (one JSON string per chart).
class ChartStore {
  static const _key = 'saved_charts_v2';
  static const _oldKey = 'saved_charts_v1';

  static Map<String, dynamic> _toJson(SavedChart s) => {
        'id': s.id,
        'name': s.birth.name,
        'dt': s.birth.wall.toIso8601String(),
        'tz': s.birth.tzHours,
        'lat': s.birth.latitude,
        'lon': s.birth.longitude,
        'place': s.birth.place,
      };

  static SavedChart _fromJson(Map<String, dynamic> m, String fallbackId) => SavedChart(
        (m['id'] as String?) ?? fallbackId,
        BirthData(
          name: m['name'] as String,
          wall: _asWall(DateTime.parse(m['dt'] as String)),
          tzHours: (m['tz'] as num).toDouble(),
          latitude: (m['lat'] as num).toDouble(),
          longitude: (m['lon'] as num).toDouble(),
          place: m['place'] as String,
        ),
      );

  static Future<List<SavedChart>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? prefs.getStringList(_oldKey) ?? [];
    final out = <SavedChart>[];
    for (var i = 0; i < raw.length; i++) {
      try {
        out.add(_fromJson(jsonDecode(raw[i]) as Map<String, dynamic>, 'old$i'));
      } catch (_) {
        // skip a corrupt entry rather than failing the whole list
      }
    }
    return out;
  }

  static Future<void> _write(List<SavedChart> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [for (final s in list) jsonEncode(_toJson(s))]);
  }

  /// Saves a new chart ([id] null) or overwrites an existing one. Returns its id.
  static Future<String> upsert(String? id, BirthData birth) async {
    final list = await load();
    final newId = id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final i = list.indexWhere((s) => s.id == newId);
    final item = SavedChart(newId, birth);
    if (i >= 0) {
      list[i] = item;
    } else {
      list.insert(0, item);
    }
    await _write(list);
    return newId;
  }

  static Future<void> delete(String id) async {
    final list = await load();
    list.removeWhere((s) => s.id == id);
    await _write(list);
  }

  /// All saved charts as one JSON text (for backup).
  static Future<String> exportJson() async => encode(await load());

  /// One chart (saved or not yet saved) as JSON text, for sharing.
  static String exportOne(BirthData b, {String? id}) => encode([
        SavedChart(id ?? 'x${DateTime.now().microsecondsSinceEpoch}', b),
      ]);

  static String encode(List<SavedChart> list) =>
      const JsonEncoder.withIndent(' ').convert({
        'app': 'astrowizard_kundli',
        'version': 1,
        'charts': [for (final s in list) _toJson(s)],
      });

  /// Merges charts from a backup text: same id = overwritten, new ids are added.
  /// Returns how many charts were imported. Throws [FormatException] on bad input.
  static Future<int> importJson(String text) async {
    final data = jsonDecode(text.trim());
    final raw = data is Map ? data['charts'] : data;
    if (raw is! List) throw const FormatException('No charts found');
    final incoming = <SavedChart>[];
    for (var i = 0; i < raw.length; i++) {
      try {
        incoming.add(_fromJson(raw[i] as Map<String, dynamic>,
            'imp${DateTime.now().microsecondsSinceEpoch}_$i'));
      } catch (_) {
        // skip entries that are not valid charts
      }
    }
    return importCharts(incoming);
  }

  /// Merges already-parsed charts (same id = overwrite). Returns the count.
  static Future<int> importCharts(List<SavedChart> incoming) async {
    if (incoming.isEmpty) throw const FormatException('No valid charts found');
    final list = await load();
    for (final c in incoming) {
      final j = list.indexWhere((s) => s.id == c.id);
      if (j >= 0) {
        list[j] = c;
      } else {
        list.add(c);
      }
    }
    await _write(list);
    return incoming.length;
  }
}
