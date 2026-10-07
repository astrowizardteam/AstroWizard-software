import 'package:xml/xml.dart';

import 'engine/models.dart';
import 'storage.dart';

/// Birth-data XML. Export writes AstroWizard's own simple layout; import is
/// tolerant: it looks for any element that carries a name / date / time /
/// time-zone / latitude / longitude (as child tags or attributes), so files
/// from other astrology software can often be read as well.
String chartsToXml(List<SavedChart> list) {
  String two(int v) => v.toString().padLeft(2, '0');
  final b = XmlBuilder();
  b.processing('xml', 'version="1.0" encoding="UTF-8"');
  b.element('AstroWizardKundli', attributes: {'version': '1'}, nest: () {
    for (final s in list) {
      final w = s.birth.wall;
      b.element('Chart', attributes: {'id': s.id}, nest: () {
        void f(String n, String v) => b.element(n, nest: v);
        f('Name', s.birth.name);
        f('Date', '${w.year.toString().padLeft(4, '0')}-${two(w.month)}-${two(w.day)}');
        f('Time', '${two(w.hour)}:${two(w.minute)}:${two(w.second)}');
        f('TimeZone', '${s.birth.tzHours}'); // hours east of UTC, e.g. 5.5
        f('Latitude', '${s.birth.latitude}'); // north positive
        f('Longitude', '${s.birth.longitude}'); // east positive
        f('Place', s.birth.place);
      });
    }
  });
  return b.buildDocument().toXmlString(pretty: true, indent: '  ');
}

const _aliases = <String, List<String>>{
  'name': ['name', 'fullname', 'personname', 'title'],
  'date': ['date', 'birthdate', 'dob', 'dateofbirth'],
  'time': ['time', 'birthtime', 'tob', 'timeofbirth'],
  'dt': ['datetime', 'dt', 'birthdatetime'],
  'tz': ['timezone', 'tz', 'utcoffset', 'zone', 'gmt', 'gmtoffset', 'timezoneoffset'],
  'lat': ['latitude', 'lat'],
  'lon': ['longitude', 'long', 'lon', 'lng'],
  'place': ['place', 'city', 'location', 'birthplace', 'town'],
  'year': ['year', 'yyyy'],
  'month': ['month', 'mm'],
  'day': ['day', 'dd'],
  'hour': ['hour', 'hh', 'hours'],
  'minute': ['minute', 'min', 'minutes'],
  'second': ['second', 'sec', 'seconds'],
};

Map<String, String> _fields(XmlElement e) {
  final raw = <String, String>{};
  for (final a in e.attributes) {
    raw[a.name.local.toLowerCase()] = a.value.trim();
  }
  for (final c in e.childElements) {
    if (c.childElements.isEmpty) raw[c.name.local.toLowerCase()] = c.innerText.trim();
  }
  final out = <String, String>{};
  _aliases.forEach((k, names) {
    for (final n in names) {
      final v = raw[n];
      if (v != null && v.isNotEmpty) {
        out[k] = v;
        break;
      }
    }
  });
  return out;
}

bool _looksLikeChart(Map<String, String> f) =>
    f.containsKey('lat') &&
    f.containsKey('lon') &&
    (f.containsKey('date') || f.containsKey('dt') || f.containsKey('year'));

/// "28.65", "28.65N", "28N39", "28:39:10 N", "77°13'E" ... -> signed degrees.
double _coord(String s, {required String pos, required String neg}) {
  final t = s.trim().toUpperCase();
  final sign = t.contains(neg) ? -1.0 : 1.0;
  final dms = RegExp(r"^[-+]?(\d+)\s*[:°]\s*(\d+)(?:\s*[:'′]\s*(\d+(?:\.\d+)?))?")
      .firstMatch(t);
  final dm = RegExp('^[-+]?(\\d+)\\s*[$pos$neg]\\s*(\\d+)').firstMatch(t);
  double v;
  if (dms != null) {
    v = double.parse(dms.group(1)!) +
        double.parse(dms.group(2)!) / 60 +
        (dms.group(3) == null ? 0 : double.parse(dms.group(3)!) / 3600);
  } else if (dm != null) {
    v = double.parse(dm.group(1)!) + double.parse(dm.group(2)!) / 60;
  } else {
    final n = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(t);
    if (n == null) throw const FormatException('bad coordinate');
    v = double.parse(n.group(0)!).abs();
    if (n.group(0)!.startsWith('-')) return -v;
  }
  return sign * v;
}

double _tz(String s) {
  final t = s.trim().toUpperCase().replaceAll('UTC', '').replaceAll('GMT', '');
  final west = t.contains('W') || t.startsWith('-');
  final hm = RegExp(r'(\d+)\s*:\s*(\d+)').firstMatch(t);
  double v;
  if (hm != null) {
    v = double.parse(hm.group(1)!) + double.parse(hm.group(2)!) / 60;
  } else {
    final n = RegExp(r'\d+(?:\.\d+)?').firstMatch(t);
    if (n == null) throw const FormatException('bad time zone');
    v = double.parse(n.group(0)!);
  }
  return west ? -v : v;
}

DateTime _wall(Map<String, String> f) {
  int y, mo, d, h = 0, mi = 0, se = 0;
  void time(String t) {
    final m = RegExp(r'(\d{1,2})\s*[:.]\s*(\d{1,2})(?:\s*[:.]\s*(\d{1,2}))?\s*([AP]M)?',
            caseSensitive: false)
        .firstMatch(t);
    if (m == null) return;
    h = int.parse(m.group(1)!);
    mi = int.parse(m.group(2)!);
    se = m.group(3) == null ? 0 : int.parse(m.group(3)!);
    final ap = m.group(4)?.toUpperCase();
    if (ap == 'PM' && h < 12) h += 12;
    if (ap == 'AM' && h == 12) h = 0;
  }

  void date(String t) {
    final iso = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(t);
    final dmy = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})').firstMatch(t);
    if (iso != null) {
      y = int.parse(iso.group(1)!);
      mo = int.parse(iso.group(2)!);
      d = int.parse(iso.group(3)!);
    } else if (dmy != null) {
      d = int.parse(dmy.group(1)!);
      mo = int.parse(dmy.group(2)!);
      y = int.parse(dmy.group(3)!);
    } else {
      throw const FormatException('bad date');
    }
  }

  y = mo = d = 0;
  if (f.containsKey('dt')) {
    final t = f['dt']!;
    date(t);
    time(t.replaceFirst(RegExp(r'^\S+[T ]'), ''));
  } else if (f.containsKey('date')) {
    date(f['date']!);
    if (f.containsKey('time')) time(f['time']!);
  } else {
    y = int.parse(f['year']!);
    mo = int.parse(f['month'] ?? '1');
    d = int.parse(f['day'] ?? '1');
    h = int.tryParse(f['hour'] ?? '') ?? 0;
    mi = int.tryParse(f['minute'] ?? '') ?? 0;
    se = int.tryParse(f['second'] ?? '') ?? 0;
  }
  return DateTime.utc(y, mo, d, h, mi, se);
}

/// Reads charts from XML text. Throws [FormatException] if none are found.
List<SavedChart> chartsFromXml(String text) {
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(text.trim());
  } on XmlException catch (e) {
    throw FormatException('Not a valid XML file (${e.message})');
  }
  final out = <SavedChart>[];
  void visit(XmlElement e) {
    final f = _fields(e);
    if (_looksLikeChart(f)) {
      try {
        out.add(SavedChart(
          e.getAttribute('id') ?? 'xml${DateTime.now().microsecondsSinceEpoch}_${out.length}',
          BirthData(
            name: f['name'] ?? '',
            wall: _wall(f),
            tzHours: f.containsKey('tz') ? _tz(f['tz']!) : 5.5,
            latitude: _coord(f['lat']!, pos: 'N', neg: 'S'),
            longitude: _coord(f['lon']!, pos: 'E', neg: 'W'),
            place: f['place'] ?? '',
          ),
        ));
      } catch (_) {
        // skip records that cannot be read
      }
      return;
    }
    e.childElements.forEach(visit);
  }

  visit(doc.rootElement);
  if (out.isEmpty) {
    throw const FormatException(
        'No birth data found in this XML (need date, time, latitude, longitude)');
  }
  return out;
}
