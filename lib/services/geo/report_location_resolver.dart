import 'package:latlong2/latlong.dart';

import '../../models/report_location.dart';
import 'baliwag_geo.dart';
import 'reverse_geocoding_service.dart';

/// Turns a raw coordinate pair (from device GPS, photo EXIF, ...) into a
/// validated, address-resolved [ReportLocation].
///
/// This is the single place that decides "is this fix good enough / inside
/// Baliwag" so the report screen and any future camera-capture flow apply
/// the exact same rules instead of duplicating boundary/geocoding logic.
class ReportLocationResolver {
  ReportLocationResolver({ReverseGeocodingService? geocoder})
    : _geocoder = geocoder ?? ReverseGeocodingService();

  final ReverseGeocodingService _geocoder;

  /// Resolves [latitude]/[longitude] into a [ReportLocation]: fills in
  /// address/barangay/street via reverse geocoding (falling back to the
  /// nearest known barangay centroid if the geocoder is unreachable), and
  /// checks the point against the Baliwag boundary.
  ///
  /// Returns null when the point falls outside Baliwag; callers should then
  /// prompt the user to pick the spot on the map instead of auto-filling
  /// the form with an out-of-area location.
  Future<ReportLocation?> resolve({
    required double latitude,
    required double longitude,
    required ReportLocationSource source,
    double? accuracyMeters,
    DateTime? capturedAt,
  }) async {
    final polygon = await BaliwagGeo.loadPolygon();
    final point = LatLng(latitude, longitude);
    if (!BaliwagGeo.isInside(point, polygon)) return null;

    final geocoded = await _geocoder.reverseGeocode(latitude, longitude);
    final barangay =
        BaliwagGeo.matchBarangayFromText(geocoded?.village) ??
        BaliwagGeo.matchBarangayFromText(geocoded?.displayName) ??
        BaliwagGeo.nearestBarangay(point);

    return ReportLocation(
      latitude: latitude,
      longitude: longitude,
      address: geocoded?.displayName,
      barangay: barangay,
      street: geocoded?.road,
      landmark: geocoded?.landmark,
      source: source,
      accuracyMeters: accuracyMeters,
      capturedAt: capturedAt,
    );
  }
}
