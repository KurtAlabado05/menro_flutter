import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as image;

class PhotoMetadata {
  const PhotoMetadata({this.latitude, this.longitude, this.takenAt});

  final double? latitude;
  final double? longitude;
  final DateTime? takenAt;
  bool get hasLocation => latitude != null && longitude != null;

  static PhotoMetadata fromTags(Map<String, IfdTag> tags) {
    double? coordinate(String name, String positive, String negative, int limit) {
      final values = tags['GPS GPS$name']?.values;
      final ref = tags['GPS GPS${name}Ref']?.printable.trim().toUpperCase();
      if (values is! IfdRatios || values.ratios.length != 3 ||
          (ref != positive && ref != negative)) {
        return null;
      }
      final parts = values.ratios.map((r) => r.toDouble()).toList();
      if (parts.any((v) => !v.isFinite || v < 0) ||
          parts[1] >= 60 || parts[2] >= 60) {
        return null;
      }
      final degrees = parts[0] + parts[1] / 60 + parts[2] / 3600;
      if (degrees > limit) return null;
      return ref == negative ? -degrees : degrees;
    }

    final lat = coordinate('Latitude', 'N', 'S', 90);
    final lng = coordinate('Longitude', 'E', 'W', 180);
    final rawDate = tags['EXIF DateTimeOriginal']?.printable;
    DateTime? date;
    final match = RegExp(
      r'^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$',
    ).firstMatch(rawDate ?? '');
    if (match != null) {
      final parts = List.generate(6, (i) => int.parse(match.group(i + 1)!));
      final candidate = DateTime(
        parts[0], parts[1], parts[2], parts[3], parts[4], parts[5],
      );
      if (candidate.year == parts[0] && candidate.month == parts[1] &&
          candidate.day == parts[2] && candidate.hour == parts[3] &&
          candidate.minute == parts[4] && candidate.second == parts[5]) {
        date = candidate;
      }
    }
    return PhotoMetadata(
      latitude: lat != null && lng != null ? lat : null,
      longitude: lat != null && lng != null ? lng : null,
      takenAt: date,
    );
  }
}

class PreparedReportPhoto {
  const PreparedReportPhoto({
    required this.bytes,
    required this.metadata,
    this.metadataWarning,
  });

  final Uint8List bytes;
  final PhotoMetadata metadata;
  final String? metadataWarning;
}

class PhotoMetadataService {
  const PhotoMetadataService({this.nativeConverter});

  final Future<Uint8List> Function(Uint8List)? nativeConverter;

  Future<PreparedReportPhoto> prepare(Uint8List original) async {
    final header = String.fromCharCodes(original.take(32));
    final isHeic = header.contains('ftyp') &&
        ['heic', 'heix', 'hevc', 'hevx', 'mif1'].any(header.contains);
    final nativePlatform = !kIsWeb &&
        {TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS}
            .contains(defaultTargetPlatform);
    if (!nativePlatform && nativeConverter == null && !isHeic) {
      return compute(_prepareReportPhoto, original);
    }
    if (!nativePlatform && nativeConverter == null) {
      throw const FormatException(
        'HEIC is not supported on this device. Choose a JPEG or PNG photo.',
      );
    }
    final (metadata, warning) = await compute(_readPhotoMetadata, original);
    final converted = nativeConverter != null
        ? await nativeConverter!(original)
        : await FlutterImageCompress.compressWithList(
            original,
            minWidth: 1280,
            minHeight: 1280,
            quality: 90,
            format: CompressFormat.jpeg,
            keepExif: false,
          );
    final sanitized = await compute(_prepareReportPhoto, converted);
    return PreparedReportPhoto(
      bytes: sanitized.bytes,
      metadata: metadata,
      metadataWarning: warning,
    );
  }
}

Future<(PhotoMetadata, String?)> _readPhotoMetadata(Uint8List original) async {
  var metadata = const PhotoMetadata();
  String? warning;
  try {
    metadata = PhotoMetadata.fromTags(
      await readExifFromBytes(original, details: false),
    );
  } on Exception catch (e) {
    debugPrint('Report photo metadata could not be read: $e');
    warning = 'Photo metadata could not be read. Use GPS or pick on map.';
  } on RangeError catch (e) {
    debugPrint('Report photo metadata is incomplete: $e');
    warning = 'Photo metadata is incomplete. Use GPS or pick on map.';
  }
  return (metadata, warning);
}

Future<PreparedReportPhoto> _prepareReportPhoto(Uint8List original) async {
  final (metadata, warning) = await _readPhotoMetadata(original);
  final decoded = image.decodeImage(original);
  if (decoded == null) {
    throw const FormatException(
      'Unsupported photo format. Choose a JPEG or PNG photo instead.',
    );
  }
  var oriented = image.bakeOrientation(decoded);
  if (oriented.width > 1280 || oriented.height > 1280) {
    oriented = image.copyResize(
      oriented,
      width: oriented.width >= oriented.height ? 1280 : null,
      height: oriented.height > oriented.width ? 1280 : null,
    );
  }
  // Read metadata locally first, then discard it from the upload payload.
  oriented.exif = image.ExifData();
  return PreparedReportPhoto(
    bytes: image.encodeJpg(oriented, quality: 75),
    metadata: metadata,
    metadataWarning: warning,
  );
}
