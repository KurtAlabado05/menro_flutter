import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// Shared Baliwag boundary + barangay reference data.
///
/// This used to live inline in `ReportLocationPickerScreen`. It is extracted
/// so the camera-first location resolver (and any future screen) can reuse
/// the exact same boundary check and barangay matching as the map picker,
/// instead of each screen drifting out of sync.
class BaliwagGeo {
  BaliwagGeo._();

  static const LatLng defaultCenter = LatLng(14.9545, 120.8995);

  /// High-precision vector nodes loaded from the bundled GeoJSON asset.
  static const String _boundaryAssetPath = 'assets/maps/baliwag_boundary.geojson';

  /// Static fallback used when the GeoJSON asset is missing or fails to
  /// parse (e.g. on a stripped-down test harness).
  static const List<LatLng> _fallbackPolygon = [
    LatLng(14.9602, 120.8521),
    LatLng(14.9714, 120.8535),
    LatLng(14.9772, 120.8614),
    LatLng(14.9865, 120.8641),
    LatLng(14.9951, 120.8722),
    LatLng(14.9991, 120.8842),
    LatLng(14.9982, 120.8991),
    LatLng(14.9911, 120.9115),
    LatLng(14.9856, 120.9192),
    LatLng(14.9821, 120.9311),
    LatLng(14.9744, 120.9395),
    LatLng(14.9612, 120.9412),
    LatLng(14.9498, 120.9381),
    LatLng(14.9415, 120.9295),
    LatLng(14.9312, 120.9211), // Hugs the Angat River border separating Bustos
    LatLng(14.9285, 120.9134),
    LatLng(14.9291, 120.9032),
    LatLng(14.9332, 120.8971),
    LatLng(14.9328, 120.8912),
    LatLng(14.9365, 120.8841), // Slices directly above Plaridel line
    LatLng(14.9351, 120.8765),
    LatLng(14.9311, 120.8711),
    LatLng(14.9412, 120.8631),
    LatLng(14.9445, 120.8692),
    LatLng(14.9491, 120.8681),
    LatLng(14.9515, 120.8612),
    LatLng(14.9561, 120.8545),
  ];

  static const Map<String, LatLng> barangayCoordinates = {
    'Bagong Nayon': LatLng(14.9590, 120.8940),
    'Barangca': LatLng(14.9350, 120.9150),
    'Calantipay': LatLng(14.9850, 120.9100),
    'Catulinan': LatLng(14.9920, 120.8900),
    'Concepcion': LatLng(14.9510, 120.8910),
    'Hinukay': LatLng(14.9780, 120.9320),
    'Makinabang': LatLng(14.9320, 120.8850),
    'Matangtubig': LatLng(14.9680, 120.9300),
    'Pagala': LatLng(14.9650, 120.8990),
    'Paitan': LatLng(14.9850, 120.8800),
    'Piel': LatLng(14.9720, 120.9150),
    'Pinagbarilan': LatLng(14.9450, 120.8750),
    'Poblacion': LatLng(14.9545, 120.8995),
    'Sabang': LatLng(14.9680, 120.9100),
    'San Jose': LatLng(14.9570, 120.8850),
    'San Roque': LatLng(14.9480, 120.9020),
    'Santa Barbara': LatLng(14.9480, 120.8920),
    'Santo Cristo': LatLng(14.9520, 120.9050),
    'Santo Niño': LatLng(14.9580, 120.8920),
    'Subic': LatLng(14.9560, 120.8840),
    'Sulivan': LatLng(14.9380, 120.9020),
    'Tangos': LatLng(14.9620, 120.8850),
    'Tarcan': LatLng(14.9410, 120.8880),
    'Tiaong': LatLng(14.9360, 120.8720),
    'Tibag': LatLng(14.9650, 120.8750),
    'Tilapayong': LatLng(14.9880, 120.9000),
    'Virgen delas Flores': LatLng(14.9610, 120.9080),
  };

  static List<String> get barangays =>
      barangayCoordinates.keys.toList(growable: false);

  static List<LatLng>? _cachedPolygon;
  static Future<List<LatLng>>? _loadingPolygon;

  /// Loads the high-fidelity OSM boundary once per app session (subsequent
  /// calls return the cached result), falling back to [_fallbackPolygon] if
  /// the asset is missing or malformed.
  static Future<List<LatLng>> loadPolygon() {
    final cached = _cachedPolygon;
    if (cached != null) return Future.value(cached);
    return _loadingPolygon ??= _loadPolygonFromAsset();
  }

  static Future<List<LatLng>> _loadPolygonFromAsset() async {
    try {
      final raw = await rootBundle.loadString(_boundaryAssetPath);
      final data = json.decode(raw) as Map<String, dynamic>;
      final points = <LatLng>[];

      final features = data['features'] as List?;
      if (features != null && features.isNotEmpty) {
        final geometry = features[0]['geometry'] as Map<String, dynamic>;
        if (geometry['type'] == 'Polygon') {
          for (final point in geometry['coordinates'][0] as List) {
            points.add(
              LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble()),
            );
          }
        } else if (geometry['type'] == 'MultiPolygon') {
          for (final point in geometry['coordinates'][0][0] as List) {
            points.add(
              LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble()),
            );
          }
        }
      }

      _cachedPolygon = points.isNotEmpty ? points : _fallbackPolygon;
    } catch (_) {
      _cachedPolygon = _fallbackPolygon;
    }
    return _cachedPolygon!;
  }

  /// Ray-casting point-in-polygon test.
  static bool isInside(LatLng point, List<LatLng> polygon) {
    var j = polygon.length - 1;
    var inside = false;
    final x = point.longitude;
    final y = point.latitude;

    for (var i = 0; i < polygon.length; i++) {
      final pi = polygon[i];
      final pj = polygon[j];
      if ((pi.latitude < y && pj.latitude >= y ||
              pj.latitude < y && pi.latitude >= y) &&
          (pi.longitude <= x || pj.longitude <= x)) {
        if (pi.longitude +
                (y - pi.latitude) /
                    (pj.latitude - pi.latitude) *
                    (pj.longitude - pi.longitude) <
            x) {
          inside = !inside;
        }
      }
      j = i;
    }
    return inside;
  }

  /// Finds the nearest known barangay centroid to [point]; used as an
  /// offline fallback when reverse geocoding is unavailable.
  static String nearestBarangay(LatLng point) {
    const distanceCalculator = Distance();
    String best = barangays.first;
    var bestDistance = double.infinity;
    barangayCoordinates.forEach((name, center) {
      final d = distanceCalculator(point, center);
      if (d < bestDistance) {
        bestDistance = d;
        best = name;
      }
    });
    return best;
  }

  /// Matches free-text geocoder output (village/suburb/neighbourhood/display
  /// name) against the known barangay list. Returns null if nothing matches.
  static String? matchBarangayFromText(String? text) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    for (final barangay in barangays) {
      if (lower.contains(barangay.toLowerCase())) return barangay;
    }
    return null;
  }
}
