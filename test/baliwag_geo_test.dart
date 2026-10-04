import 'package:cenro_application/services/geo/baliwag_geo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A simple 4-point square for deterministic point-in-polygon checks,
  // independent of the real Baliwag boundary data.
  const square = [
    LatLng(0, 0),
    LatLng(0, 10),
    LatLng(10, 10),
    LatLng(10, 0),
  ];

  group('BaliwagGeo.isInside', () {
    test('returns true for a point inside the polygon', () {
      expect(BaliwagGeo.isInside(const LatLng(5, 5), square), isTrue);
    });

    test('returns false for a point outside the polygon', () {
      expect(BaliwagGeo.isInside(const LatLng(20, 20), square), isFalse);
    });

    test('returns false for an empty polygon', () {
      expect(BaliwagGeo.isInside(const LatLng(5, 5), const []), isFalse);
    });
  });

  group('BaliwagGeo.matchBarangayFromText', () {
    test('matches a known barangay name case-insensitively', () {
      expect(
        BaliwagGeo.matchBarangayFromText('poblacion, Baliwag, Bulacan'),
        'Poblacion',
      );
    });

    test('returns null when no barangay name is present', () {
      expect(BaliwagGeo.matchBarangayFromText('Some other place'), isNull);
    });

    test('returns null for empty or null text', () {
      expect(BaliwagGeo.matchBarangayFromText(''), isNull);
      expect(BaliwagGeo.matchBarangayFromText(null), isNull);
    });
  });

  group('BaliwagGeo.nearestBarangay', () {
    test('returns the barangay whose centroid is closest to the point', () {
      final poblacionCenter = BaliwagGeo.barangayCoordinates['Poblacion']!;
      final nearby = LatLng(
        poblacionCenter.latitude + 0.0005,
        poblacionCenter.longitude + 0.0005,
      );
      expect(BaliwagGeo.nearestBarangay(nearby), 'Poblacion');
    });
  });

  group('BaliwagGeo.loadPolygon', () {
    test('resolves to a non-empty polygon', () async {
      final polygon = await BaliwagGeo.loadPolygon();
      expect(polygon, isNotEmpty);
    });
  });
}
