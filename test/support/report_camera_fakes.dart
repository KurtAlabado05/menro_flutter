import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:cenro_application/services/media/report_camera_service.dart';
import 'package:flutter/widgets.dart';

const testFrontCamera = CameraDescription(
  name: 'Laptop webcam',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 0,
);

const testBackCamera = CameraDescription(
  name: 'Rear camera',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

class FakeReportCameraService extends ReportCameraService {
  FakeReportCameraService({
    required this.bytes,
    this.descriptions = const [testFrontCamera],
  });

  final Uint8List bytes;
  List<CameraDescription> descriptions;
  Object? initializationError;
  Object? captureError;
  Future<void>? initialization;
  Future<void>? capture;
  final List<CameraDescription> opened = [];
  final List<FakeReportCameraSession> sessions = [];

  @override
  Future<List<CameraDescription>> cameras() async => descriptions;

  @override
  ReportCameraSession open(CameraDescription description) {
    opened.add(description);
    final session = FakeReportCameraSession(this);
    sessions.add(session);
    return session;
  }
}

class FakeReportCameraSession implements ReportCameraSession {
  FakeReportCameraSession(this.service);

  final FakeReportCameraService service;
  bool disposed = false;
  int captures = 0;

  @override
  Future<void> initialize() async {
    if (service.initialization != null) await service.initialization!;
    final error = service.initializationError;
    if (error != null) throw error;
  }

  @override
  Widget buildPreview() => const Text('Live webcam preview');

  @override
  Future<XFile> takePicture() async {
    captures++;
    if (service.capture != null) await service.capture!;
    final error = service.captureError;
    if (error != null) throw error;
    return XFile.fromData(
      service.bytes,
      name: 'webcam.jpg',
      mimeType: 'image/jpeg',
    );
  }

  @override
  Future<void> dispose() async => disposed = true;
}
