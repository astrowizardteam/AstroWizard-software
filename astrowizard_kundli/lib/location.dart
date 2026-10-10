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
  try {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 30)),
    );
    return (lat: p.latitude, lon: p.longitude);
  } on TimeoutException {
    throw Exception('Could not get a location fix. Try again near a window or with mobile data on');
  } catch (_) {
    throw Exception('Could not read the location');
  }
}
