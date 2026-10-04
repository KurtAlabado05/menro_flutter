import 'package:flutter/foundation.dart';

/// Where a [ReportLocation] came from. Used to show provenance ("From photo
/// GPS", "Picked on map", ...) and to decide whether a later, lower-priority
/// source is allowed to overwrite the current selection.
///
/// Priority (highest first): [manual] > [photoExif] > [cameraGps] >
/// [deviceGps] > [unknown].
enum ReportLocationSource { manual, photoExif, cameraGps, deviceGps, unknown }

extension ReportLocationSourceLabel on ReportLocationSource {
  /// Short, user-facing description of where a location came from, shown as
  /// a provenance chip on the incident-location card.
  String get label {
    switch (this) {
      case ReportLocationSource.manual:
        return 'Picked on map';
      case ReportLocationSource.photoExif:
        return 'From photo location';
      case ReportLocationSource.cameraGps:
        return 'From camera GPS';
      case ReportLocationSource.deviceGps:
        return 'From your location';
      case ReportLocationSource.unknown:
        return 'Location set';
    }
  }
}

/// How confident we are in a fix's horizontal accuracy, used to decide
/// whether it can be auto-accepted, should be labelled "approximate", or
/// needs the user to confirm the spot on the map.
enum LocationAccuracyLevel { precise, approximate, poor }

/// Bands a horizontal accuracy reading (meters) into a [LocationAccuracyLevel].
/// A null/unknown accuracy is treated as merely "approximate" rather than
/// "poor", since most manual/geocoded locations don't carry an accuracy at
/// all but are otherwise trustworthy.
LocationAccuracyLevel accuracyLevelFor(double? accuracyMeters) {
  if (accuracyMeters == null) return LocationAccuracyLevel.approximate;
  if (!accuracyMeters.isFinite || accuracyMeters <= 0) {
    return LocationAccuracyLevel.poor;
  }
  if (accuracyMeters <= 50) return LocationAccuracyLevel.precise;
  if (accuracyMeters <= 150) return LocationAccuracyLevel.approximate;
  return LocationAccuracyLevel.poor;
}

/// A fully-resolved incident location: coordinates plus the address details
/// shown in the report form. Both the GPS auto-fill path and the map picker
/// produce this type so the rest of the app only has to deal with one shape.
@immutable
class ReportLocation {
  const ReportLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.barangay,
    this.street,
    this.landmark,
    this.source = ReportLocationSource.unknown,
    this.accuracyMeters,
    this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final String? address;
  final String? barangay;
  final String? street;
  final String? landmark;
  final ReportLocationSource source;

  /// Horizontal accuracy of the fix, in meters, when known.
  final double? accuracyMeters;

  /// When the underlying fix was taken (e.g. photo EXIF timestamp). Null for
  /// a fresh device GPS read or a manual map pick.
  final DateTime? capturedAt;

  /// Coordinates formatted as a human-readable fallback address.
  String get coordinatesLabel =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  /// The best address string to display: [address] if set, otherwise the
  /// raw coordinates.
  String get displayAddress {
    final trimmed = address?.trim();
    return (trimmed != null && trimmed.isNotEmpty) ? trimmed : coordinatesLabel;
  }

  ReportLocation copyWith({
    double? latitude,
    double? longitude,
    String? address,
    String? barangay,
    String? street,
    String? landmark,
    ReportLocationSource? source,
    double? accuracyMeters,
    DateTime? capturedAt,
  }) {
    return ReportLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      barangay: barangay ?? this.barangay,
      street: street ?? this.street,
      landmark: landmark ?? this.landmark,
      source: source ?? this.source,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  @override
  String toString() =>
      'ReportLocation(lat: $latitude, lng: $longitude, source: $source, '
      'barangay: $barangay, address: $address)';
}
