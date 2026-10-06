import 'ashtakavarga.dart';
import 'bhavabala.dart';
import 'insight.dart';
import 'constants.dart';
import 'panchang.dart';
import 'relations.dart';
import 'shadbala.dart';
import 'varga.dart';
import 'chara_dasha.dart';
import 'vimshottari.dart';

export 'ashtakavarga.dart';
export 'bhavabala.dart';
export 'insight.dart';
export 'constants.dart';
export 'panchang.dart';
export 'relations.dart';
export 'shadbala.dart';
export 'varga.dart';
export 'chara_dasha.dart';
export 'vimshottari.dart';

class BirthData {
  final String name;

  /// Wall-clock birth time at the birth place, to the second. Stored as a
  /// UTC-flagged DateTime on purpose, so device time-zone / DST rules never
  /// shift it. It is NOT a real UTC instant.
  final DateTime wall;
  final double tzHours; // UTC offset of the birth place, e.g. 5.5 for IST
  final double latitude;
  final double longitude; // east positive
  final String place;

  const BirthData({
    required this.name,
    required this.wall,
    required this.tzHours,
    required this.latitude,
    required this.longitude,
    required this.place,
  });

  BirthData copyWith({String? name, DateTime? wall, double? tzHours,
          double? latitude, double? longitude, String? place}) =>
      BirthData(
        name: name ?? this.name,
        wall: wall ?? this.wall,
        tzHours: tzHours ?? this.tzHours,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        place: place ?? this.place,
      );

  /// The real UTC instant of birth.
  DateTime get utc => wall.subtract(Duration(microseconds: (tzHours * 3600e6).round()));

  /// "Now" expressed as wall-clock time at the birth place's UTC offset.
  DateTime nowAtBirthZone() => DateTime.now()
      .toUtc()
      .add(Duration(microseconds: (tzHours * 3600e6).round()));
}

class PlanetPosition {
  final String name;
  final double longitude; // sidereal, 0..360
  final double speed; // deg/day
  final int house; // whole-sign house from lagna, 1..12

  const PlanetPosition({
    required this.name,
    required this.longitude,
    required this.speed,
    required this.house,
  });

  bool get retrograde => speed < 0;
  int get signIndex => (longitude ~/ 30) % 12;
  double get degreeInSign => longitude % 30;
  int get nakshatraIndex => (longitude ~/ kNakshatraSpan) % 27;
  int get pada => ((longitude % kNakshatraSpan) ~/ (kNakshatraSpan / 4)) + 1;
  String get sign => kSigns[signIndex];
  String get nakshatra => kNakshatras[nakshatraIndex];

  /// Vimshottari lord of the nakshatra.
  String get nakshatraLord => kDashaOrder[nakshatraIndex % 9];
}

class KundliChart {
  final BirthData birth;
  final double julianDayUt;
  final double ayanamsa;
  final double ascendant; // sidereal longitude
  final double midheaven;
  final Map<String, PlanetPosition> planets;
  final Map<int, VargaChart> vargas; // keyed by division (1, 3, 9, 10)
  final List<DashaPeriod> vimshottari; // 9 mahadashas
  final List<CharaPeriod> chara; // Jaimini Chara maha periods (2 cycles)
  final Panchang panchang;
  final Ashtakavarga ashtakavarga;
  final ShadbalaResult shadbala;
  final Relations relations;
  final List<BhavaBala> bhavaBala;
  final Map<String, PlanetInsight> insight;

  const KundliChart({
    required this.birth,
    required this.julianDayUt,
    required this.ayanamsa,
    required this.ascendant,
    required this.midheaven,
    required this.planets,
    required this.vargas,
    required this.vimshottari,
    required this.chara,
    required this.panchang,
    required this.ashtakavarga,
    required this.shadbala,
    required this.relations,
    required this.bhavaBala,
    required this.insight,
  });

  int get lagnaSign => (ascendant ~/ 30) % 12;
  double get lagnaDegree => ascendant % 30;
  int get lagnaNakshatraIndex => (ascendant ~/ kNakshatraSpan) % 27;
  String get lagnaNakshatraLord => kDashaOrder[lagnaNakshatraIndex % 9];
  int get lagnaPada =>
      ((ascendant % kNakshatraSpan) ~/ (kNakshatraSpan / 4)) + 1;
}
