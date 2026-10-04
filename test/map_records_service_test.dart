import 'package:cenro_application/services/map_records_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

MapDocument document(String id, {Object? latitude = 14.9545, Object? longitude = 120.8995}) =>
    MapDocument(id, {
      'title': id,
      'latitude': latitude,
      'longitude': longitude,
    });

void main() {
  test('citizens and organizations cannot request all reports', () {
    for (final role in ['citizen', 'individual', 'organization', '']) {
      expect(
        MapRecordsService.canReadAllReports(claims: {}, profileRole: role),
        isFalse,
      );
    }
  });

  test('staff profiles and trusted claims match workflow read permissions', () {
    for (final role in [
      'admin', 'super_admin', 'inspection_officer', 'receiving_clerk',
      'denr_officer', 'staff', 'menro_staff', 'denr_staff', 'menro', 'denr',
    ]) {
      expect(
        MapRecordsService.canReadAllReports(claims: {}, profileRole: role),
        isTrue,
      );
      expect(
        MapRecordsService.canReadAllReports(
          claims: {'role': role},
          profileRole: 'citizen',
        ),
        isTrue,
      );
    }
    expect(
      MapRecordsService.canReadAllReports(
        claims: {'admin': true},
        profileRole: 'citizen',
      ),
      isTrue,
    );
  });

  test('report permission failure preserves the projects layer', () async {
    final service = MapRecordsService(
      reportsLoader: () async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      ),
      projectsLoader: () async => [document('project')],
    );
    final result = await service.load();
    expect(result.reports.error, contains('access'));
    expect(result.projects.error, isNull);
    expect(result.projects.records.single.id, 'project');
  });

  test('project failure preserves reports and a retry recovers', () async {
    var fail = true;
    final service = MapRecordsService(
      reportsLoader: () async => [document('report')],
      projectsLoader: () async {
        if (fail) {
          throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
        }
        return [document('project')];
      },
    );
    final failed = await service.load();
    expect(failed.reports.records.single.id, 'report');
    expect(failed.projects.error, contains('retry'));
    fail = false;
    final recovered = await service.load();
    expect(recovered.projects.error, isNull);
    expect(recovered.projects.records.single.id, 'project');
  });

  test('unusable coordinates are counted without discarding valid records', () async {
    final service = MapRecordsService(
      reportsLoader: () async => [
        document('valid', latitude: '14.9545', longitude: '120.8995'),
        document('missing', latitude: null),
        document('invalid', latitude: 'bad'),
        document('out-of-range', longitude: 181),
        document('infinite', latitude: double.infinity),
      ],
      projectsLoader: () async => [],
    );
    final result = await service.load();
    expect(result.reports.error, isNull);
    expect(result.reports.records.single.id, 'valid');
    expect(result.reports.unmappedCount, 4);
  });

  test('map data does not depend on unrelated report fields being parseable', () {
    final record = MapRecord.fromDocument(
      const MapDocument('report', {
        'category': 'Illegal Dumping',
        'latitude': 14.9545,
        'longitude': 120.8995,
        'statusHistory': 'legacy value',
        'upvotes': 'legacy value',
      }),
      'report',
    );
    expect(record!.title, 'Illegal Dumping');
    expect(record.latitude, 14.9545);
  });
}
