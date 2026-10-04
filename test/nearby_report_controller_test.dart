import 'dart:async';

import 'package:cenro_application/models/report_model.dart';
import 'package:cenro_application/services/nearby_report_controller.dart';
import 'package:flutter_test/flutter_test.dart';

ReportModel draft(String id) => ReportModel(
  id: id, title: 'Dumped waste', description: 'Environmental issue',
  category: id, location: 'Poblacion', latitude: 14.9545, longitude: 120.8995,
  submittedBy: '', submittedByName: '', submittedAt: DateTime.now(),
);

void main() {
  test('debounces rapid location/category changes into the latest lookup', () async {
    final calls = <String>[];
    final controller = NearbyReportController(
      debounce: Duration.zero,
      findNearby: (report) async {
        calls.add(report.id);
        return report;
      },
    );
    addTearDown(controller.dispose);
    controller.check(draft('first'));
    controller.check(draft('second'));
    expect(controller.isChecking, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(calls, ['second']);
    expect(controller.report!.id, 'second');
    expect(controller.isChecking, isFalse);
  });

  test('out-of-order completions cannot replace a newer match', () async {
    final first = Completer<ReportModel?>();
    final second = Completer<ReportModel?>();
    final controller = NearbyReportController(
      debounce: Duration.zero,
      findNearby: (report) => report.id == 'first' ? first.future : second.future,
    );
    addTearDown(controller.dispose);
    controller.check(draft('first'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    controller.check(draft('second'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    second.complete(draft('second'));
    await Future<void>.delayed(Duration.zero);
    first.complete(draft('first'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.report!.id, 'second');
  });

  test('clearing an invalid location discards pending results', () async {
    final result = Completer<ReportModel?>();
    final controller = NearbyReportController(
      debounce: Duration.zero, findNearby: (_) => result.future,
    );
    addTearDown(controller.dispose);
    controller.check(draft('first'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    controller.check(null);
    result.complete(draft('first'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.report, isNull);
    expect(controller.isChecking, isFalse);
  });

  test('lookup failures remain visible and retry clears them', () async {
    var attempts = 0;
    final controller = NearbyReportController(
      debounce: Duration.zero,
      findNearby: (_) async {
        if (++attempts == 1) throw StateError('Offline');
        return null;
      },
    );
    addTearDown(controller.dispose);
    controller.check(draft('first'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.error, isNotNull);
    controller.check(draft('first'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.error, isNull);
    expect(attempts, 2);
  });

  test('disposing suppresses notification from an in-flight lookup', () async {
    final result = Completer<ReportModel?>();
    final controller = NearbyReportController(
      debounce: Duration.zero, findNearby: (_) => result.future,
    );
    controller.check(draft('first'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    controller.dispose();
    result.complete(draft('first'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.report, isNull);
  });
}
