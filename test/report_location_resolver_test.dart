import 'dart:convert';

import 'package:cenro_application/models/report_location.dart';
import 'package:cenro_application/services/geo/baliwag_geo.dart';
import 'package:cenro_application/services/geo/report_location_resolver.dart';
import 'package:cenro_application/services/geo/reverse_geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ReportLocationResolver resolverWithReverseGeocodeResponse(
    Map<String, dynamic> body,
  ) {
    final client = MockClient((request) async {
      return http.Response(json.encode(body), 200);
    });
    return ReportLocationResolver(geocoder: ReverseGeocodingService(client: client));
  }

  group('ReportLocationResolver.resolve', () {
    test('returns null for a point outside the Baliwag boundary', () async {
      final resolver = resolverWithReverseGeocodeResponse({
        'display_name': 'Nowhere',
        'address': <String, dynamic>{},
      });

      final result = await resolver.resolve(
        latitude: 0,
        longitude: 0,
        source: ReportLocationSource.deviceGps,
      );

      expect(result, isNull);
    });

    test('resolves a point inside Baliwag using the geocoded address', () async {
      final resolver = resolverWithReverseGeocodeResponse({
        'display_name': 'Poblacion, Baliwag, Bulacan',
        'address': {
          'road': 'J.P. Rizal St.',
          'village': 'Poblacion',
        },
      });

      final center = BaliwagGeo.defaultCenter;
      final result = await resolver.resolve(
        latitude: center.latitude,
        longitude: center.longitude,
        source: ReportLocationSource.deviceGps,
        accuracyMeters: 12,
      );

      expect(result, isNotNull);
      expect(result!.barangay, 'Poblacion');
      expect(result.street, 'J.P. Rizal St.');
      expect(result.address, 'Poblacion, Baliwag, Bulacan');
      expect(result.source, ReportLocationSource.deviceGps);
      expect(result.accuracyMeters, 12);
    });

    test('falls back to the nearest barangay when geocoding fails', () async {
      final client = MockClient((request) async => http.Response('', 500));
      final resolver = ReportLocationResolver(
        geocoder: ReverseGeocodingService(client: client),
      );

      final center = BaliwagGeo.defaultCenter;
      final result = await resolver.resolve(
        latitude: center.latitude,
        longitude: center.longitude,
        source: ReportLocationSource.deviceGps,
      );

      expect(result, isNotNull);
      expect(result!.barangay, 'Poblacion');
      expect(result.address, isNull);
    });
  });
}
