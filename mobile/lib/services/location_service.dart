import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../config/constants.dart';

class LocationService {
  Future<Position?> getCurrentPosition() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return null;
    }
    if (perm == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
    );
  }

  double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;

  bool isInServiceArea(double lat, double lon) {
    final dist = distanceKm(lat, lon, AppConstants.anchorLat, AppConstants.anchorLon);
    return dist <= AppConstants.serviceRadiusKm;
  }
}
