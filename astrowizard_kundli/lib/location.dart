import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Where the person is right now (asks for the location permission if needed).
/// Throws an [Exception] whose message is safe to show to the user.
Future<({double lat, double lon})> deviceLocation() async {
  LocationPermission perm;
  try {
    perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
  } catch (_) {
    throw Exception('Could not ask for location permission');
  }
  if (perm == LocationPermission.denied) {
    throw Exception('Location permission was not given');
  }
  if (perm == LocationPermission.deniedForever) {
    throw Exception('Location permission is blocked. Allow it in Phone Settings > Apps > AstroWizard > Permissions');
  }
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Location (GPS) is switched off on this phone');
  }
  // Fast: last known position, if the phone has one.
  try {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return (lat: last.latitude, lon: last.longitude);
  } catch (_) {}
  // Network-based fix first (quick, needs mobile data / WiFi), then the GPS
  // itself, which works without any internet (open sky or near a window).
  for (final (acc, secs) in const [(LocationAccuracy.low, 10), (LocationAccuracy.best, 45)]) {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: acc, timeLimit: Duration(seconds: secs)),
      );
      return (lat: p.latitude, lon: p.longitude);
    } on TimeoutException {
      continue;
    } catch (_) {
      continue;
    }
  }
  throw Exception('Could not get a GPS fix. Go near a window / outdoors, or tap "Choose city"');
}
