import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Returns the current GPS position with timeout and cached fallback.
  static Future<Position> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
        return _defaultFallbackPosition();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
        return _defaultFallbackPosition();
      }

      // Fast GPS position with 4-second time limit to avoid freezing the UI
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 4),
        ),
      );
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      return _defaultFallbackPosition();
    }
  }

  /// Get cached last known position instantly for zero-delay UI rendering
  static Future<Position?> getLastKnownLocation() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  static Position _defaultFallbackPosition() {
    return Position(
      longitude: 96.1951,
      latitude: 16.8661,
      timestamp: DateTime.now(),
      accuracy: 50.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  /// Stream of position updates.
  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Calculates distance in meters between two GPS coordinates
  static double calculateDistance(double startLatitude, double startLongitude, double endLatitude, double endLongitude) {
    return Geolocator.distanceBetween(startLatitude, startLongitude, endLatitude, endLongitude);
  }
}
