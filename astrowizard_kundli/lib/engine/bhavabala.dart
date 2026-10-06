import 'constants.dart';
import 'shadbala.dart';

/// Minimum Bhava bala considered adequate: 7 rupas (420 virupas).
const double kMinBhavaBala = 420.0;

enum BhavaSignClass { nara, jalachara, chatushpada, keeta }

BhavaSignClass signClass(int sign, double deg) {
  if (const [2, 5, 6, 10].contains(sign) || (sign == 8 && deg < 15)) {
    return BhavaSignClass.nara;
  }
  if (const [3, 11].contains(sign) || (sign == 9 && deg >= 15)) {
    return BhavaSignClass.jalachara;
  }
  if (sign == 7) return BhavaSignClass.keeta;
  return BhavaSignClass.chatushpada;
}

class BhavaBala {
  final int house; // 1..12
  final int sign;
  final String lord;
  final BhavaSignClass signClass;
  final double adhipati; // Shadbala total of the house lord
  final double dig;
  final double drishti;

  const BhavaBala({
    required this.house,
    required this.sign,
    required this.lord,
    required this.signClass,
    required this.adhipati,
    required this.dig,
    required this.drishti,
  });

  double get total => adhipati + dig + drishti;
  double get rupas => total / 60;
  double get ratio => total / kMinBhavaBala;
}

double _angDiff(double a, double b) => (((a - b + 180) % 360) - 180).abs();

/// Bhava bala of the 12 houses. House madhya = ascendant degree in each sign
/// (equal-house). Components: Bhavadhipati (lord's Shadbala), Bhava dig bala
/// and Bhava drishti bala (benefic minus malefic aspects, one quarter).
List<BhavaBala> computeBhavaBala({
  required Map<String, double> lon,
  required double asc,
  required double mc,
  required ShadbalaResult shadbala,
}) {
  final out = <BhavaBala>[];
  for (var h = 1; h <= 12; h++) {
    final mid = (asc + 30.0 * (h - 1)) % 360;
    final sign = mid ~/ 30;
    final lord = kSignLords[sign];
    final cls = signClass(sign, mid % 30);
    final strong = switch (cls) {
      BhavaSignClass.nara => asc,
      BhavaSignClass.jalachara => (mc + 180) % 360,
      BhavaSignClass.chatushpada => mc,
      BhavaSignClass.keeta => (asc + 180) % 360,
    };
    final dig = _angDiff(mid, (strong + 180) % 360) / 3;
    var acc = 0.0;
    for (final q in kSeven) {
      final v = sphutaDrishti((mid - lon[q]!) % 360, q);
      acc += shadbala.benefic[q]! ? v : -v;
    }
    out.add(BhavaBala(
      house: h,
      sign: sign,
      lord: lord,
      signClass: cls,
      adhipati: shadbala.planets[lord]!.total,
      dig: dig,
      drishti: acc / 4,
    ));
  }
  return out;
}
