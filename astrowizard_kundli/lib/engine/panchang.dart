import 'dart:math' as math;

import 'constants.dart';

const List<String> _tithi = [
  'Pratipada', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami', 'Shashthi',
  'Saptami', 'Ashtami', 'Navami', 'Dashami', 'Ekadashi', 'Dwadashi',
  'Trayodashi', 'Chaturdashi',
];
const List<String> _yoga = [
  'Vishkambha', 'Priti', 'Ayushman', 'Saubhagya', 'Shobhana', 'Atiganda',
  'Sukarma', 'Dhriti', 'Shoola', 'Ganda', 'Vriddhi', 'Dhruva', 'Vyaghata',
  'Harshana', 'Vajra', 'Siddhi', 'Vyatipata', 'Variyana', 'Parigha', 'Shiva',
  'Siddha', 'Sadhya', 'Shubha', 'Shukla', 'Brahma', 'Indra', 'Vaidhriti',
];
const List<String> _karana7 = [
  'Bava', 'Balava', 'Kaulava', 'Taitila', 'Gara', 'Vanija', 'Vishti',
];

const List<String> kVara = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];
const List<String> kVaraLord = [
  'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn',
];
const List<String> kChaldean = [
  'Sun', 'Venus', 'Mercury', 'Moon', 'Saturn', 'Jupiter', 'Mars',
];

/// Julian day (Gregorian) for a calendar date; [hour] may be outside 0..24.
double julianDay(int year, int month, int day, double hour) {
  var y = year;
  var m = month;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (y + 4716)).floor() +
      (30.6001 * (m + 1)).floor() +
      day +
      b -
      1524.5 +
      hour / 24.0;
}

/// Sunrise/sunset as local clock hours (NOAA equations, ~1 minute accuracy).
/// Returns null when the sun does not rise or set (polar regions).
({double rise, double set})? sunTimes(
    int year, int month, int day, double lat, double lon, double tz) {
  double rad(double d) => d * math.pi / 180;
  final jd = julianDay(year, month, day, 12.0 - tz);
  final t = (jd - 2451545.0) / 36525.0;
  final l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360;
  final m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
  final e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
  final c = math.sin(rad(m)) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
      math.sin(rad(2 * m)) * (0.019993 - 0.000101 * t) +
      math.sin(rad(3 * m)) * 0.000289;
  final trueLong = l0 + c;
  final omega = 125.04 - 1934.136 * t;
  final lam = trueLong - 0.00569 - 0.00478 * math.sin(rad(omega));
  final eps0 = 23 +
      (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
  final eps = eps0 + 0.00256 * math.cos(rad(omega));
  final decl = math.asin(math.sin(rad(eps)) * math.sin(rad(lam)));
  final y = math.pow(math.tan(rad(eps) / 2), 2).toDouble();
  final eq = 4 *
      (180 / math.pi) *
      (y * math.sin(2 * rad(l0)) -
          2 * e * math.sin(rad(m)) +
          4 * e * y * math.sin(rad(m)) * math.cos(2 * rad(l0)) -
          0.5 * y * y * math.sin(4 * rad(l0)) -
          1.25 * e * e * math.sin(2 * rad(m)));
  final cosHa = math.cos(rad(90.833)) / (math.cos(rad(lat)) * math.cos(decl)) -
      math.tan(rad(lat)) * math.tan(decl);
  if (cosHa < -1 || cosHa > 1) return null;
  final ha = math.acos(cosHa) * 180 / math.pi;
  final sr = (720 - 4 * (lon + ha) - eq) / 60 + tz;
  final ss = (720 - 4 * (lon - ha) - eq) / 60 + tz;
  return (rise: sr, set: ss);
}

/// Weekday index (Sunday = 0) of the Vedic day, which starts at sunrise.
/// [wall] is a UTC-flagged wall-clock DateTime.
int vedicVara(DateTime wall, double lat, double lon, double tz) {
  final st = sunTimes(wall.year, wall.month, wall.day, lat, lon, tz);
  final hours = wall.hour + wall.minute / 60 + wall.second / 3600;
  var wd = wall.weekday % 7; // Dart: Mon=1..Sun=7
  if (st != null && hours < st.rise) wd = (wd + 6) % 7;
  return wd;
}

class Panchang {
  final int tithiNumber; // 1..30
  final String tithi;
  final String paksha;
  final String nakshatra;
  final String yoga;
  final String karana;
  final String vara;
  final double? sunrise; // local clock hours
  final double? sunset;

  const Panchang({
    required this.tithiNumber,
    required this.tithi,
    required this.paksha,
    required this.nakshatra,
    required this.yoga,
    required this.karana,
    required this.vara,
    required this.sunrise,
    required this.sunset,
  });
}

Panchang computePanchang(double sun, double moon, DateTime wall, double lat,
    double lon, double tz) {
  final diff = (moon - sun) % 360;
  final tn = (diff ~/ 12) + 1;
  final k = diff ~/ 6;
  final String karana;
  if (k == 0) {
    karana = 'Kimstughna';
  } else if (k >= 57) {
    karana = const ['Shakuni', 'Chatushpada', 'Naga'][k - 57];
  } else {
    karana = _karana7[(k - 1) % 7];
  }
  final p = ((tn - 1) % 15) + 1;
  final tname = p < 15 ? _tithi[p - 1] : (tn == 15 ? 'Purnima' : 'Amavasya');
  final st = sunTimes(wall.year, wall.month, wall.day, lat, lon, tz);
  return Panchang(
    tithiNumber: tn,
    tithi: tname,
    paksha: tn <= 15 ? 'Shukla' : 'Krishna',
    nakshatra: kNakshatras[(moon ~/ kNakshatraSpan) % 27],
    yoga: _yoga[(((sun + moon) % 360) ~/ kNakshatraSpan) % 27],
    karana: karana,
    vara: kVara[vedicVara(wall, lat, lon, tz)],
    sunrise: st?.rise,
    sunset: st?.set,
  );
}

/// "06:26" style text for clock hours.
String clockText(double? hours) {
  if (hours == null) return '--';
  var h = hours % 24;
  var m = (h * 60).round();
  final hh = (m ~/ 60) % 24;
  final mm = m % 60;
  return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}
