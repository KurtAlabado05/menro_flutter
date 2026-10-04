enum PhotoIdentificationFailure {
  noMatch,
  lowConfidence,
  unavailable,
  rateLimited,
  unauthenticated,
  invalidPhoto,
  backendNotReady,
  storageUnavailable,
  onSiteTooFar,
  onSiteGpsUnreliable,
  onSiteLocationUnavailable,
  onSiteTreeNotPinned,
}

class PhotoIdentificationException implements Exception {
  const PhotoIdentificationException(this.failure, {this.photoIndex});
  final PhotoIdentificationFailure failure;
  final int? photoIndex;

  String get title => switch (failure) {
    PhotoIdentificationFailure.noMatch => 'Photo could not be recognized',
    PhotoIdentificationFailure.lowConfidence =>
      'Plant identification uncertain',
    PhotoIdentificationFailure.unauthenticated => 'Sign in again',
    PhotoIdentificationFailure.invalidPhoto => 'Replace the photo',
    PhotoIdentificationFailure.rateLimited => 'Analysis is busy',
    PhotoIdentificationFailure.unavailable => 'Analysis unavailable',
    PhotoIdentificationFailure.backendNotReady => 'Photo validation not ready',
    PhotoIdentificationFailure.storageUnavailable =>
      'Could not save photo validation',
    PhotoIdentificationFailure.onSiteTooFar => 'Too far from the pinned tree',
    PhotoIdentificationFailure.onSiteGpsUnreliable => 'Location not accurate enough',
    PhotoIdentificationFailure.onSiteLocationUnavailable =>
      'Location needed for on-site photo',
    PhotoIdentificationFailure.onSiteTreeNotPinned => 'Pin the tree first',
  };

  String get message => switch (failure) {
    PhotoIdentificationFailure.noMatch =>
      'We could not recognize a plant in this photo. Use a clear photo of the actual tree leaves or bark. An unrecognized photo cannot be submitted.',
    PhotoIdentificationFailure.lowConfidence =>
      'We could not identify the plant confidently from this photo. Try a close-up of leaves or distinctive bark with minimal background. A clear photo can still be difficult to identify.',
    PhotoIdentificationFailure.unauthenticated =>
      'Your session has expired. Sign in again to analyze your photos.',
    PhotoIdentificationFailure.invalidPhoto =>
      'This photo cannot be processed. Choose a valid JPG or PNG photo of the trees.',
    PhotoIdentificationFailure.rateLimited =>
      'Photo analysis is busy. Keep your draft and try again later.',
    PhotoIdentificationFailure.unavailable =>
      'We could not validate your photos right now. Check your connection and retry. Your application cannot be submitted until validation succeeds.',
    PhotoIdentificationFailure.backendNotReady =>
      'The photo validation service is not ready. This is not a rejection of your photo. Contact MENRO or the app administrator. Your application cannot be submitted until the service is available.',
    PhotoIdentificationFailure.storageUnavailable =>
      'Photo analysis finished, but the server could not save its validation result. This is not a problem with your photo or phone connection. Retry later or contact MENRO. Submission remains blocked until validation can be saved.',
    PhotoIdentificationFailure.onSiteTooFar =>
      'The species could not be confirmed, and this photo was taken too far from the tree you pinned. Stand at the tree and retake it, or correct the pin in Trees & Location.',
    PhotoIdentificationFailure.onSiteGpsUnreliable =>
      'The species could not be confirmed, and your location is not accurate enough to prove the photo was taken at the tree. Move to open sky, wait a moment, and retake it.',
    PhotoIdentificationFailure.onSiteLocationUnavailable =>
      'On-site photos need your current location to show they were taken at the tree. Turn on location and allow access, then try again.',
    PhotoIdentificationFailure.onSiteTreeNotPinned =>
      'Pin the tree on the map in Trees & Location before taking an on-site photo.',
  };

  /// True when a leafless or dead tree may still be documented on site.
  bool get allowsOnSiteFallback =>
      failure == PhotoIdentificationFailure.noMatch ||
      failure == PhotoIdentificationFailure.lowConfidence;

  @override
  String toString() =>
      'PhotoIdentificationException(${failure.name}'
      '${photoIndex == null ? '' : ', photoIndex: $photoIndex'})';
}

class TreePhotoValidation {
  static const String verified = 'verified';
  static const String unverifiedOnSite = 'unverified_onsite';

  const TreePhotoValidation({
    required this.id,
    required this.urls,
    required this.expiresAt,
    this.speciesVerification = verified,
    this.unverifiedUrls = const [],
  });
  final String id;
  final List<String> urls;
  final DateTime expiresAt;
  final String speciesVerification;

  /// Photos accepted only as on-site evidence; species is checked at inspection.
  final List<String> unverifiedUrls;

  bool get requiresInspection => speciesVerification == unverifiedOnSite;
}

/// Live in-app capture taken at the tree, with the GPS fix read right after.
class OnSiteTreeCapture {
  const OnSiteTreeCapture({
    required this.url,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });
  final String url;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;

  Map<String, Object> toJson() => {
    'url': url,
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
  };
}
