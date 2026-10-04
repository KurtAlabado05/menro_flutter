import 'package:cenro_application/models/report_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReportLocation', () {
    test('displayAddress uses the address when present', () {
      const location = ReportLocation(
        latitude: 14.9545,
        longitude: 120.8995,
        address: 'Poblacion, Baliwag, Bulacan',
      );
      expect(location.displayAddress, 'Poblacion, Baliwag, Bulacan');
    });

    test('displayAddress falls back to coordinates when address is blank', () {
      const location = ReportLocation(
        latitude: 14.9545,
        longitude: 120.8995,
        address: '   ',
      );
      expect(location.displayAddress, location.coordinatesLabel);
      expect(location.coordinatesLabel, '14.95450, 120.89950');
    });

    test('copyWith overrides only the given fields', () {
      const location = ReportLocation(
        latitude: 1,
        longitude: 2,
        barangay: 'Poblacion',
        source: ReportLocationSource.deviceGps,
      );
      final updated = location.copyWith(barangay: 'Tangos');
      expect(updated.barangay, 'Tangos');
      expect(updated.latitude, 1);
      expect(updated.longitude, 2);
      expect(updated.source, ReportLocationSource.deviceGps);
    });
  });
}
