import 'package:flutter/services.dart' show rootBundle;

class City {
  final String name;
  final double lat;
  final double lon;
  final double tz; // UTC offset in hours
  const City(this.name, this.lat, this.lon, this.tz);
}

/// Small built-in atlas so the app works offline. Users can also type
/// latitude / longitude (and UTC offset) manually. A full world atlas comes in a later phase.
const List<City> kCities = [
  City('Agra, UP', 27.1767, 78.0081, 5.5),
  City('Delhi', 28.6139, 77.2090, 5.5),
  City('Mumbai, MH', 19.0760, 72.8777, 5.5),
  City('Kolkata, WB', 22.5726, 88.3639, 5.5),
  City('Chennai, TN', 13.0827, 80.2707, 5.5),
  City('Bengaluru, KA', 12.9716, 77.5946, 5.5),
  City('Hyderabad, TS', 17.3850, 78.4867, 5.5),
  City('Ahmedabad, GJ', 23.0225, 72.5714, 5.5),
  City('Pune, MH', 18.5204, 73.8567, 5.5),
  City('Jaipur, RJ', 26.9124, 75.7873, 5.5),
  City('Lucknow, UP', 26.8467, 80.9462, 5.5),
  City('Kanpur, UP', 26.4499, 80.3319, 5.5),
  City('Varanasi, UP', 25.3176, 82.9739, 5.5),
  City('Patna, BR', 25.5941, 85.1376, 5.5),
  City('Bhopal, MP', 23.2599, 77.4126, 5.5),
  City('Indore, MP', 22.7196, 75.8577, 5.5),
  City('Chandigarh', 30.7333, 76.7794, 5.5),
  City('Dehradun, UK', 30.3165, 78.0322, 5.5),
  City('Ujjain, MP', 23.1765, 75.7885, 5.5),
  City('Haridwar, UK', 29.9457, 78.1642, 5.5),
  City('Kathmandu, Nepal', 27.7172, 85.3240, 5.75),
  City('Dhaka, Bangladesh', 23.8103, 90.4125, 6.0),
  City('Colombo, Sri Lanka', 6.9271, 79.8612, 5.5),
  City('London, UK', 51.5074, -0.1278, 0.0),
  City('New York, USA', 40.7128, -74.0060, -5.0),
  City('Dubai, UAE', 25.2048, 55.2708, 4.0),
  City('Surat, GJ', 21.1702, 72.8311, 5.5),
  City('Vadodara, GJ', 22.3072, 73.1812, 5.5),
  City('Rajkot, GJ', 22.3039, 70.8022, 5.5),
  City('Vadnagar, GJ', 23.7810, 72.6370, 5.5),
  City('Nagpur, MH', 21.1458, 79.0882, 5.5),
  City('Nashik, MH', 19.9975, 73.7898, 5.5),
  City('Aurangabad, MH', 19.8762, 75.3433, 5.5),
  City('Thane, MH', 19.2183, 72.9781, 5.5),
  City('Panaji, Goa', 15.4909, 73.8278, 5.5),
  City('Mysuru, KA', 12.2958, 76.6394, 5.5),
  City('Mangaluru, KA', 12.9141, 74.8560, 5.5),
  City('Hubballi, KA', 15.3647, 75.1240, 5.5),
  City('Kochi, KL', 9.9312, 76.2673, 5.5),
  City('Thiruvananthapuram, KL', 8.5241, 76.9366, 5.5),
  City('Kozhikode, KL', 11.2588, 75.7804, 5.5),
  City('Coimbatore, TN', 11.0168, 76.9558, 5.5),
  City('Madurai, TN', 9.9252, 78.1198, 5.5),
  City('Tiruchirappalli, TN', 10.7905, 78.7047, 5.5),
  City('Visakhapatnam, AP', 17.6868, 83.2185, 5.5),
  City('Vijayawada, AP', 16.5062, 80.6480, 5.5),
  City('Tirupati, AP', 13.6288, 79.4192, 5.5),
  City('Warangal, TS', 17.9689, 79.5941, 5.5),
  City('Bhubaneswar, OD', 20.2961, 85.8245, 5.5),
  City('Cuttack, OD', 20.4625, 85.8830, 5.5),
  City('Puri, OD', 19.8135, 85.8312, 5.5),
  City('Ranchi, JH', 23.3441, 85.3096, 5.5),
  City('Jamshedpur, JH', 22.8046, 86.2029, 5.5),
  City('Raipur, CG', 21.2514, 81.6296, 5.5),
  City('Guwahati, AS', 26.1445, 91.7362, 5.5),
  City('Shillong, ML', 25.5788, 91.8933, 5.5),
  City('Gangtok, SK', 27.3389, 88.6065, 5.5),
  City('Imphal, MN', 24.8170, 93.9368, 5.5),
  City('Siliguri, WB', 26.7271, 88.3953, 5.5),
  City('Gaya, BR', 24.7914, 85.0002, 5.5),
  City('Muzaffarpur, BR', 26.1209, 85.3647, 5.5),
  City('Prayagraj, UP', 25.4358, 81.8463, 5.5),
  City('Gorakhpur, UP', 26.7606, 83.3732, 5.5),
  City('Meerut, UP', 28.9845, 77.7064, 5.5),
  City('Noida, UP', 28.5355, 77.3910, 5.5),
  City('Ghaziabad, UP', 28.6692, 77.4538, 5.5),
  City('Mathura, UP', 27.4924, 77.6737, 5.5),
  City('Bareilly, UP', 28.3670, 79.4304, 5.5),
  City('Aligarh, UP', 27.8974, 78.0880, 5.5),
  City('Moradabad, UP', 28.8386, 78.7733, 5.5),
  City('Jhansi, UP', 25.4484, 78.5685, 5.5),
  City('Gurugram, HR', 28.4595, 77.0266, 5.5),
  City('Faridabad, HR', 28.4089, 77.3178, 5.5),
  City('Ambala, HR', 30.3782, 76.7767, 5.5),
  City('Amritsar, PB', 31.6340, 74.8723, 5.5),
  City('Ludhiana, PB', 30.9010, 75.8573, 5.5),
  City('Jalandhar, PB', 31.3260, 75.5762, 5.5),
  City('Shimla, HP', 31.1048, 77.1734, 5.5),
  City('Srinagar, JK', 34.0837, 74.7973, 5.5),
  City('Jammu, JK', 32.7266, 74.8570, 5.5),
  City('Jodhpur, RJ', 26.2389, 73.0243, 5.5),
  City('Udaipur, RJ', 24.5854, 73.7125, 5.5),
  City('Kota, RJ', 25.2138, 75.8648, 5.5),
  City('Ajmer, RJ', 26.4499, 74.6399, 5.5),
  City('Bikaner, RJ', 28.0229, 73.3119, 5.5),
  City('Gwalior, MP', 26.2183, 78.1828, 5.5),
  City('Jabalpur, MP', 23.1815, 79.9864, 5.5),
  City('Nashik Road, MH', 19.9500, 73.8300, 5.5),
  City('Haldwani, UK', 29.2183, 79.5130, 5.5),
  City('Rishikesh, UK', 30.0869, 78.2676, 5.5),
  City('Karachi, Pakistan', 24.8607, 67.0011, 5.0),
  City('Lahore, Pakistan', 31.5204, 74.3587, 5.0),
  City('Singapore', 1.3521, 103.8198, 8.0),
  City('Kuala Lumpur, Malaysia', 3.1390, 101.6869, 8.0),
  City('Toronto, Canada', 43.6532, -79.3832, -5.0),
  City('Los Angeles, USA', 34.0522, -118.2437, -8.0),
  City('Chicago, USA', 41.8781, -87.6298, -6.0),
  City('Sydney, Australia', -33.8688, 151.2093, 10.0),
];


/// Offline atlas: the curated list above plus ~7,000 Indian towns and the
/// larger world cities from `assets/cities.txt` (name|region|lat|lon|tz).
/// World cities carry their standard (non-DST) UTC offset; edit it manually
/// for a birth that happened during daylight saving.
class CityDb {
  static List<City> _all = kCities;
  static List<String> _lower = [for (final c in kCities) c.name.toLowerCase()];

  static Future<void> load() async {
    try {
      final text = await rootBundle.loadString('assets/cities.txt');
      final seen = <String>{for (final c in kCities) c.name.toLowerCase()};
      final all = <City>[...kCities];
      for (final line in text.split('\n')) {
        final f = line.split('|');
        if (f.length < 5) continue;
        final name = f[1].isEmpty ? f[0] : '${f[0]}, ${f[1]}';
        if (!seen.add(name.toLowerCase())) continue;
        final lat = double.tryParse(f[2]), lon = double.tryParse(f[3]), tz = double.tryParse(f[4]);
        if (lat == null || lon == null || tz == null) continue;
        all.add(City(name, lat, lon, tz));
      }
      _all = all;
      _lower = [for (final c in all) c.name.toLowerCase()];
    } catch (_) {
      // keep the built-in list
    }
  }

  /// Names starting with [query] first, then names containing it.
  static List<City> search(String query, {int limit = 10}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _all.take(limit).toList();
    final starts = <City>[], inside = <City>[];
    for (var i = 0; i < _all.length && starts.length < limit; i++) {
      final n = _lower[i];
      if (n.startsWith(q)) {
        starts.add(_all[i]);
      } else if (inside.length < limit && n.contains(q)) {
        inside.add(_all[i]);
      }
    }
    return [...starts, ...inside].take(limit).toList();
  }

  static City? byName(String name) {
    final n = name.toLowerCase();
    final i = _lower.indexOf(n);
    return i < 0 ? null : _all[i];
  }
}
