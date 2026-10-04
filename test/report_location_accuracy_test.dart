import 'package:cenro_application/models/report_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('accuracyLevelFor', () {
    test('null accuracy is treated as approximate', () {
      expect(accuracyLevelFor(null), LocationAccuracyLevel.approximate);
    });

    test('accuracy at or under 50m is precise', () {
      expect(accuracyLevelFor(10), LocationAccuracyLevel.precise);
      expect(accuracyLevelFor(50), LocationAccuracyLevel.precise);
    });

    test('accuracy between 50m and 150m is approximate', () {
      expect(accuracyLevelFor(51), LocationAccuracyLevel.approximate);
      expect(accuracyLevelFor(150), LocationAccuracyLevel.approximate);
    });

    test('accuracy over 150m is poor', () {
      expect(accuracyLevelFor(151), LocationAccuracyLevel.poor);
      expect(accuracyLevelFor(500), LocationAccuracyLevel.poor);
    });

    test('zero, negative and non-finite accuracy are not precise', () {
      for (final value in [0.0, -1.0, double.nan, double.infinity]) {
        expect(accuracyLevelFor(value), LocationAccuracyLevel.poor);
      }
    });
  });

  group('ReportLocationSourceLabel', () {
    test('every source has a non-empty label', () {
      for (final source in ReportLocationSource.values) {
        expect(source.label, isNotEmpty);
      }
    });

    test('manual source is labelled as picked on map', () {
      expect(ReportLocationSource.manual.label, contains('map'));
    });
  });
}
