import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../cloudinary_image_service.dart';

enum ReportPhotoUploadStatus { queued, uploading, uploaded, failed, removed }

typedef ReportPhotoUploader =
    Future<String> Function(Uint8List bytes, String fileName);

class ReportPhotoUpload {
  ReportPhotoUpload._(this.id, this.bytes);

  final String id;
  final Uint8List bytes;
  ReportPhotoUploadStatus status = ReportPhotoUploadStatus.queued;
  String? url;
  Object? error;
  Completer<void> _settled = Completer<void>();
}

class ReportPhotoUploadException implements Exception {
  const ReportPhotoUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ReportPhotoUploadQueue extends ChangeNotifier {
  ReportPhotoUploadQueue({ReportPhotoUploader? uploader, this.concurrency = 2})
    : assert(concurrency > 0),
      _uploader = uploader ?? _uploadToCloudinary;

  final int concurrency;
  final ReportPhotoUploader _uploader;
  final List<ReportPhotoUpload> _pending = [];
  final Set<ReportPhotoUpload> _entries = {};
  final String _draftId = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  int _sequence = 0;
  int _active = 0;
  bool _disposed = false;

  static Future<String> _uploadToCloudinary(Uint8List bytes, String name) {
    const cloudinary = CloudinaryImageService(
      cloudName: String.fromEnvironment(
        'REPORT_CLOUDINARY_CLOUD_NAME',
        defaultValue: 'dfo5l4d4t',
      ),
      uploadPreset: String.fromEnvironment(
        'REPORT_CLOUDINARY_UPLOAD_PRESET',
        defaultValue: 'flutter_upload_preset',
      ),
    );
    return cloudinary.uploadImage(
      bytes: bytes,
      fileName: name,
      timeout: const Duration(seconds: 60),
    );
  }

  ReportPhotoUpload add(Uint8List bytes) {
    if (_disposed) throw StateError('The report upload queue is closed.');
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Photo is empty.');
    }
    final entry = ReportPhotoUpload._(
      'reports_${_draftId}_${_sequence++}',
      bytes,
    );
    _entries.add(entry);
    _pending.add(entry);
    _pump();
    notifyListeners();
    return entry;
  }

  void retry(ReportPhotoUpload entry) {
    if (_disposed ||
        !_entries.contains(entry) ||
        entry.status != ReportPhotoUploadStatus.failed) {
      throw StateError('Only a failed, attached photo can be retried.');
    }
    entry.error = null;
    entry._settled = Completer<void>();
    entry.status = ReportPhotoUploadStatus.queued;
    _pending.add(entry);
    _pump();
    notifyListeners();
  }

  void remove(ReportPhotoUpload entry) {
    _entries.remove(entry);
    _pending.remove(entry);
    entry.status = ReportPhotoUploadStatus.removed;
    if (!entry._settled.isCompleted) entry._settled.complete();
    if (!_disposed) notifyListeners();
  }

  Future<List<String>> waitForUrls(List<ReportPhotoUpload> selected) async {
    if (selected.isEmpty) {
      throw const ReportPhotoUploadException('Attach at least one photo.');
    }
    await Future.wait(selected.map((entry) => entry._settled.future));
    final urls = <String>[];
    for (final entry in selected) {
      if (_disposed ||
          entry.status != ReportPhotoUploadStatus.uploaded ||
          entry.url == null) {
        throw const ReportPhotoUploadException(
          'Some photos could not upload. Retry or remove the failed photos before submitting.',
        );
      }
      urls.add(entry.url!);
    }
    return urls;
  }

  void _pump() {
    while (!_disposed && _active < concurrency && _pending.isNotEmpty) {
      final entry = _pending.removeAt(0);
      _active++;
      entry.status = ReportPhotoUploadStatus.uploading;
      unawaited(_run(entry));
    }
  }

  Future<void> _run(ReportPhotoUpload entry) async {
    try {
      final url = await _uploader(entry.bytes, '${entry.id}.jpg');
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const FormatException(
          'Photo upload returned an invalid HTTPS URL.',
        );
      }
      if (!_disposed && entry.status != ReportPhotoUploadStatus.removed) {
        entry.url = url;
        entry.status = ReportPhotoUploadStatus.uploaded;
      }
    } catch (e, stack) {
      debugPrint('Report photo upload failed: $e\n$stack');
      if (!_disposed && entry.status != ReportPhotoUploadStatus.removed) {
        entry.error = e;
        entry.status = ReportPhotoUploadStatus.failed;
      }
    } finally {
      if (!entry._settled.isCompleted) entry._settled.complete();
      _active--;
      _pump();
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final entry in _entries.toList()) {
      remove(entry);
    }
    super.dispose();
  }
}
