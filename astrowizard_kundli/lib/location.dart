import 'package:geolocator/geolocator.dart';

/// Where the person is right now (asks for the location permission if needed).
/// Returns (lat, lon) or throws a [String]-message [Exception] that is safe to show.
Future<({double lat, double lon})> deviceLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Location is switched off on this phone');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied) {
    throw Exception('Location permission was not given');
  }
  if (perm == LocationPermission.deniedForever) {
    throw Exception('Location permission is blocked. Allow it in the phone Settings > Apps > AstroWizard');
  }
  final p = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)),
  );
  return (lat: p.latitude, lon: p.longitude);
}
