import 'panchang.dart';

/// Hours (relative to the birth moment) at which Gulika and Mandi rise.
///
/// The day (sunrise to sunset) or the night (sunset to next sunrise) is cut into
/// 8 equal parts. Day parts are ruled in weekday order starting with the lord of
/// the Vedic weekday, night parts start with the 5th lord from it; the 8th part
/// has no lord. Gulika = start of Saturn's part, Mandi = middle of Saturn's part
/// (Jagannatha Hora / Parashara's Light convention). The ascendant at that
/// moment is the upagraha's longitude. Returns null near the poles.
({double gulika, double mandi})? upagrahaOffsets(
    DateTime wall, double lat, double lon, double tz) {
  final h = wall.hour + wall.minute / 60 + wall.second / 3600;
  final today = sunTimes(wall.year, wall.month, wall.day, lat, lon, tz);
  if (today == null) return null;
  var day = false;
  late double start, end;
  if (h < today.rise) {
    final pv = wall.subtract(const Duration(days: 1));
    final p = sunTimes(pv.year, pv.month, pv.day, lat, lon, tz);
    if (p == null) return null;
    start = p.set - 24;
    end = today.rise;
  } else if (h >= today.set) {
    final nx = wall.add(const Duration(days: 1));
    final n = sunTimes(nx.year, nx.month, nx.day, lat, lon, tz);
    if (n == null) return null;
    start = today.set;
    end = n.rise + 24;
  } else {
    day = true;
    start = today.rise;
    end = today.set;
  }
  final wd = vedicVara(wall, lat, lon, tz);
  final k = day ? (6 - wd) % 7 : (6 - (wd + 4)) % 7;
  final len = (end - start) / 8;
  final g = start + k * len;
  return (gulika: g - h, mandi: g + len / 2 - h);
}
