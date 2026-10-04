import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../services/media/report_camera_service.dart';

class ReportCameraScreen extends StatefulWidget {
  const ReportCameraScreen({
    super.key,
    this.cameraService = const ReportCameraService(),
  });

  final ReportCameraService cameraService;

  @override
  State<ReportCameraScreen> createState() => _ReportCameraScreenState();
}

class _ReportCameraScreenState extends State<ReportCameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  ReportCameraSession? _session;
  Future<void> _operation = Future.value();
  int _generation = 0;
  int _selectedCamera = 0;
  bool _loading = true;
  bool _capturing = false;
  bool _foreground = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openCamera();
  }

  void _enqueue(Future<void> Function() action) {
    _operation = _operation.then((_) => action());
  }

  Future<void> _releaseCamera() async {
    final session = _session;
    _session = null;
    if (session == null) return;
    try {
      await session.dispose();
    } catch (e, stack) {
      debugPrint('Report camera disposal failed: $e\n$stack');
    }
  }

  void _openCamera() {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    // Serialize open, capture and release: native cameras cannot be safely
    // reopened while an earlier initialization or capture is still running.
    _enqueue(() async {
      await _releaseCamera();
      if (!mounted || !_foreground || generation != _generation) return;
      try {
        if (_cameras.isEmpty) {
          _cameras = await widget.cameraService.cameras();
          _selectedCamera = _cameras.indexWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
          );
          if (_selectedCamera < 0) _selectedCamera = 0;
        }
        if (!mounted || !_foreground || generation != _generation) return;
        if (_cameras.isEmpty) {
          throw CameraException('NoCamera', 'No camera was found.');
        }
        final session = widget.cameraService.open(_cameras[_selectedCamera]);
        _session = session;
        await session.initialize();
        if (!mounted || !_foreground || generation != _generation) {
          await _releaseCamera();
          return;
        }
        setState(() => _loading = false);
      } catch (e, stack) {
        debugPrint('Report camera initialization failed: $e\n$stack');
        await _releaseCamera();
        if (mounted && generation == _generation) {
          setState(() {
            _loading = false;
            _error = _cameraError(e);
          });
        }
      }
    });
  }

  String _cameraError(Object error) {
    if (error is CameraException) {
      switch (error.code) {
        case 'NoCamera':
          return 'No camera was found. Connect a webcam or configure the Android emulator camera, then retry.';
        case 'CameraAccessDenied':
        case 'CameraAccessDeniedWithoutPrompt':
        case 'CameraAccessRestricted':
          return 'Camera access is blocked. Allow camera access in your browser or device settings. On the web, use HTTPS or localhost, then retry.';
      }
      final description = error.description;
      if (description != null && description.isNotEmpty) {
        return 'Could not use the camera: $description\n'
            'Check camera permissions and close other apps using the webcam.';
      }
    }
    return 'Could not open the camera. Use HTTPS or localhost in a browser, '
        'allow camera access, and check that your webcam is connected.';
  }

  void _capture() {
    final session = _session;
    if (session == null || _loading || _capturing || !_foreground) return;
    final generation = _generation;
    setState(() {
      _capturing = true;
      _error = null;
    });
    _enqueue(() async {
      try {
        if (!mounted || generation != _generation) return;
        final photo = await session.takePicture();
        if (!mounted ||
            !_foreground ||
            generation != _generation ||
            ModalRoute.of(context)?.isCurrent != true) {
          return;
        }
        Navigator.pop(context, photo);
      } catch (e, stack) {
        debugPrint('Report camera capture failed: $e\n$stack');
        if (mounted && generation == _generation) {
          setState(() => _error = _cameraError(e));
        }
      } finally {
        if (mounted) setState(() => _capturing = false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (foreground) {
      _openCamera();
    } else {
      _generation++;
      setState(() => _loading = true);
      _enqueue(_releaseCamera);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _foreground = false;
    _enqueue(_releaseCamera);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take report photo'),
        actions: [
          if (_cameras.length > 1)
            IconButton(
              tooltip: 'Switch camera',
              icon: const Icon(Icons.cameraswitch_outlined),
              onPressed: _loading || _capturing
                  ? null
                  : () {
                      _selectedCamera = (_selectedCamera + 1) % _cameras.length;
                      _openCamera();
                    },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Opening camera...'),
                        ],
                      ),
                    )
                  : session == null
                      ? const Center(child: Icon(Icons.no_photography_outlined, size: 64))
                      : Center(child: session.buildPreview()),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _loading || _capturing ? null : _openCamera,
                      child: const Text('Retry camera'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: session == null || _loading || _capturing
                    ? null
                    : _capture,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(_capturing ? 'Capturing...' : 'Take photo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
