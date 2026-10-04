import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:cenro_application/screens/report/report_camera_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/report_camera_fakes.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    FakeReportCameraService service, {
    ValueChanged<XFile?>? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await Navigator.push<XFile>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportCameraScreen(cameraService: service),
                  ),
                );
                onResult?.call(result);
              },
              child: const Text('Open camera'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open camera'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('webcam preview captures a photo and releases camera', (
    tester,
  ) async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final service = FakeReportCameraService(bytes: bytes);
    XFile? result;
    await mount(tester, service, onResult: (photo) => result = photo);
    await tester.pumpAndSettle();
    expect(find.text('Live webcam preview'), findsOneWidget);
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(await result!.readAsBytes(), bytes);
    expect(service.sessions.single.captures, 1);
    expect(service.sessions.single.disposed, isTrue);
  });

  testWidgets('prefers rear camera and can switch to webcam', (tester) async {
    final service = FakeReportCameraService(
      bytes: Uint8List(1),
      descriptions: [testFrontCamera, testBackCamera],
    );
    await mount(tester, service);
    await tester.pumpAndSettle();
    expect(service.opened.single, testBackCamera);
    await tester.tap(find.byTooltip('Switch camera'));
    await tester.pumpAndSettle();
    expect(service.opened.last, testFrontCamera);
    expect(service.sessions.first.disposed, isTrue);
  });

  testWidgets('permission failure is visible and retry opens preview', (
    tester,
  ) async {
    final service = FakeReportCameraService(bytes: Uint8List(1))
      ..initializationError = CameraException('CameraAccessDenied', 'Denied');
    await mount(tester, service);
    await tester.pumpAndSettle();
    expect(find.textContaining('Camera access is blocked'), findsOneWidget);
    expect(service.sessions.single.disposed, isTrue);
    service.initializationError = null;
    await tester.tap(find.text('Retry camera'));
    await tester.pumpAndSettle();
    expect(find.text('Live webcam preview'), findsOneWidget);
  });

  testWidgets('no webcam shows explicit error and can retry discovery', (
    tester,
  ) async {
    final service = FakeReportCameraService(
      bytes: Uint8List(1),
      descriptions: [],
    );
    await mount(tester, service);
    await tester.pumpAndSettle();
    expect(find.textContaining('No camera was found'), findsOneWidget);
    expect(service.opened, isEmpty);
    service.descriptions = [testFrontCamera];
    await tester.tap(find.text('Retry camera'));
    await tester.pumpAndSettle();
    expect(find.text('Live webcam preview'), findsOneWidget);
  });

  testWidgets('capture failure leaves preview and allows another capture', (
    tester,
  ) async {
    final service = FakeReportCameraService(bytes: Uint8List(1))
      ..captureError = CameraException('captureFailed', 'Camera is busy');
    await mount(tester, service);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Camera is busy'), findsOneWidget);
    expect(find.text('Live webcam preview'), findsOneWidget);
    service.captureError = null;
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(service.sessions.single.captures, 2);
    expect(service.sessions.single.disposed, isTrue);
  });

  testWidgets('background releases camera and resume opens it again', (
    tester,
  ) async {
    final service = FakeReportCameraService(bytes: Uint8List(1));
    await mount(tester, service);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(service.sessions.single.disposed, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(service.sessions.length, 2);
    expect(find.text('Live webcam preview'), findsOneWidget);
  });

  testWidgets(
    'closing during initialization disposes late camera without navigation',
    (tester) async {
      final ready = Completer<void>();
      final service = FakeReportCameraService(bytes: Uint8List(1))
        ..initialization = ready.future;
      await mount(tester, service);
      expect(find.text('Opening camera...'), findsOneWidget);
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));
      ready.complete();
      await tester.pumpAndSettle();
      expect(service.sessions.single.disposed, isTrue);
      expect(find.text('Open camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('closing during capture does not pop the underlying screen', (
    tester,
  ) async {
    final shutter = Completer<void>();
    final service = FakeReportCameraService(bytes: Uint8List(1))
      ..capture = shutter.future;
    XFile? result;
    await mount(tester, service, onResult: (photo) => result = photo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take photo'));
    await tester.pump();
    await tester.pageBack();
    // Complete while the outgoing camera route is still mounted/animating.
    shutter.complete();
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Open camera'), findsOneWidget);
    expect(service.sessions.single.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
