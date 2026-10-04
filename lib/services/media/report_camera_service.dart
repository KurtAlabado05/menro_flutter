import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

abstract class ReportCameraSession {
  Future<void> initialize();
  Widget buildPreview();
  Future<XFile> takePicture();
  Future<void> dispose();
}

class ReportCameraService {
  const ReportCameraService();

  Future<List<CameraDescription>> cameras() => availableCameras();

  ReportCameraSession open(CameraDescription description) =>
      _PluginCameraSession(description);
}

class _PluginCameraSession implements ReportCameraSession {
  _PluginCameraSession(CameraDescription description)
      : _controller = CameraController(
          description,
          ResolutionPreset.high,
          enableAudio: false,
        );

  final CameraController _controller;

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Widget buildPreview() => CameraPreview(_controller);

  @override
  Future<XFile> takePicture() => _controller.takePicture();

  @override
  Future<void> dispose() => _controller.dispose();
}
