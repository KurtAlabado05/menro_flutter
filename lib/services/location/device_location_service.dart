import 'package:geolocator/geolocator.dart';

/// Outcome of a location-availability check. Lets callers show the right
/// message without re-deriving it from raw service/permission booleans at
/// every call site.
enum LocationAvailability {
  available,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

extension LocationAvailabilityMessage on LocationAvailability {
  /// A short, user-facing explanation for why a fix couldn't be obtained.
  /// Null when location is available (nothing to show).
  String? get message {
    switch (this) {
      case LocationAvailability.available:
        return null;
      case LocationAvailability.serviceDisabled:
        return 'Location services are off. Turn them on or pick the spot on the map.';
      case LocationAvailability.permissionDenied:
      case LocationAvailability.permissionDeniedForever:
        return 'Location permission is off. You can still pick the spot on the map.';
    }
  }
}

/// A single resolved GPS fix: coordinates, horizontal accuracy, and when it
/// was taken.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
}

/// Thin wrapper around [Geolocator] that centralizes permission/service
/// checks and the "warm up with a cached fix, then refine" pattern: callers
/// can show [lastKnown] on screen instantly while [currentFix] resolves in
/// the background, instead of making the user stare at a spinner for the
/// whole GPS lock.
class DeviceLocationService {
  const DeviceLocationService();

  /// Checks whether the location service is on and permission is granted,
  /// requesting permission if it hasn't been decided yet.
  Future<LocationAvailability> checkAvailability({
    bool requestPermission = true,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationAvailability.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return LocationAvailability.permissionDenied;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationAvailability.permissionDeniedForever;
    }
    return LocationAvailability.available;
  }

  /// Returns the OS's last cached fix if it's younger than [maxAge], or null
  /// if there isn't one, it's stale, or the platform doesn't support it.
  Future<LocationFix?> lastKnown({
    Duration maxAge = const Duration(minutes: 2),
  }) async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      final age = DateTime.now().difference(position.timestamp);
      if (age.isNegative || age > maxAge) return null;
      return LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        timestamp: position.timestamp,
      );
    } catch (_) {
      return null;
    }
  }

  /// Requests a fresh high-accuracy fix, bounded by [timeout].
  Future<LocationFix> currentFix({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeout,
      ),
    );
    return LocationFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      timestamp: position.timestamp,
    );
  }
}
