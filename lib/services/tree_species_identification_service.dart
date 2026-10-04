import 'dart:convert';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants/api_config.dart';
import '../core/constants/tree_species_aliases.dart';
import '../models/species_identification_result.dart';
import '../models/photo_identification_error.dart';

class TreeSpeciesIdentificationService {
  const TreeSpeciesIdentificationService({this.client, this.tokenProvider});
  final http.Client? client;
  final Future<String?> Function()? tokenProvider;

  static const double lowConfidenceThreshold = 0.5;

  Future<SpeciesIdentificationResult> identifyFromUrls({
    required List<String> evidencePhotoUrls,
    List<String> organs = const [],
  }) async {
    final decoded = await _post(ApiConfig.identifySpeciesUrl, {
        'imageUrls': evidencePhotoUrls,
        if (organs.isNotEmpty) 'organs': organs,
    });
    final result = SpeciesIdentificationResult.fromJson(decoded);
    final best = result.bestMatch;
    if (best == null || best.scientificName.trim().isEmpty) {
      throw const PhotoIdentificationException(PhotoIdentificationFailure.noMatch);
    }
    return SpeciesIdentificationResult(
      suggestions: result.suggestions,
      bestMatch: result.bestMatch,
      evidencePhotoUrls: evidencePhotoUrls,
      identifiedAt: result.identifiedAt ?? DateTime.now(),
    );
  }

  Future<TreePhotoValidation> validateTreePhotos(
    List<String> urls, {
    List<OnSiteTreeCapture> onSiteCaptures = const [],
    double? treeLatitude,
    double? treeLongitude,
  }) async {
    final captures = onSiteCaptures.where((c) => urls.contains(c.url)).toList();
    final body = await _post(ApiConfig.validateTreePhotosUrl, {
      'imageUrls': urls,
      if (captures.isNotEmpty && treeLatitude != null && treeLongitude != null) ...{
        'onSiteCaptures': [for (final capture in captures) capture.toJson()],
        'treeLocation': {'latitude': treeLatitude, 'longitude': treeLongitude},
      },
    });
    final id = body['validationId'];
    final expiry = DateTime.tryParse(body['expiresAt']?.toString() ?? '');
    final evidence = body['evidencePhotoUrls'];
    final status = body['speciesVerification'] ?? TreePhotoValidation.verified;
    final indexes = body['unverifiedPhotoIndexes'] ?? const [];
    final validIndexes = indexes is List &&
        indexes.every((i) => i is int && i >= 0 && i < urls.length);
    final unverified = validIndexes
        ? [for (final i in indexes) urls[i as int]]
        : const <String>[];
    final consistentStatus = status == TreePhotoValidation.verified
        ? unverified.isEmpty
        : status == TreePhotoValidation.unverifiedOnSite && unverified.isNotEmpty &&
            unverified.every(captures.map((c) => c.url).contains);
    if (id is! String || id.isEmpty || expiry == null ||
        !expiry.isAfter(DateTime.now()) || evidence is! List ||
        !listEquals(evidence, urls) || !validIndexes || !consistentStatus) {
      debugPrint('Photo validation returned an invalid receipt.');
      throw const PhotoIdentificationException(PhotoIdentificationFailure.unavailable);
    }
    return TreePhotoValidation(
      id: id, urls: List.unmodifiable(urls), expiresAt: expiry,
      speciesVerification: status as String,
      unverifiedUrls: List.unmodifiable(unverified),
    );
  }

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, Object> body) async {
    final photos = body['imageUrls'];
    if (photos is! List || photos.isEmpty) {
      throw const PhotoIdentificationException(PhotoIdentificationFailure.invalidPhoto);
    }
    final ownedClient = client ?? http.Client();
    try {
      final token = await (tokenProvider != null
          ? tokenProvider!()
          : FirebaseAuth.instance.currentUser?.getIdToken() ?? Future.value(null));
      if (token == null || token.isEmpty) {
        throw const PhotoIdentificationException(PhotoIdentificationFailure.unauthenticated);
      }
      final response = await ownedClient.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 90));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final failure = failureFromResponse(response.statusCode, response.body);
        debugPrint('Photo analysis failed: HTTP ${response.statusCode}; '
            'failure=${failure.failure.name}; photoIndex=${failure.photoIndex}');
        throw failure;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException('Invalid API result');
      return decoded;
    } on PhotoIdentificationException {
      rethrow;
    } catch (error, stack) {
      debugPrint('Photo analysis request failed: $error\n$stack');
      throw const PhotoIdentificationException(PhotoIdentificationFailure.unavailable);
    } finally {
      if (client == null) ownedClient.close();
    }
  }

  static PhotoIdentificationException failureFromResponse(int status, String body) {
    Map<String, dynamic>? payload;
    try {
      final value = jsonDecode(body);
      if (value is Map<String, dynamic>) payload = value;
    } on FormatException {
      // Older proxies can return plain text; do not expose it to users.
    }
    final code = payload?['code'];
    final failure = switch (code) {
      'no_match' => PhotoIdentificationFailure.noMatch,
      'low_confidence' => PhotoIdentificationFailure.lowConfidence,
      'invalid_photos' => PhotoIdentificationFailure.invalidPhoto,
      'unauthenticated' => PhotoIdentificationFailure.unauthenticated,
      'rate_limited' => PhotoIdentificationFailure.rateLimited,
      'backend_not_ready' || 'failed-precondition' =>
        PhotoIdentificationFailure.backendNotReady,
      'validation_storage_unavailable' =>
        PhotoIdentificationFailure.storageUnavailable,
      'onsite_too_far' => PhotoIdentificationFailure.onSiteTooFar,
      'onsite_gps_unreliable' => PhotoIdentificationFailure.onSiteGpsUnreliable,
      _ => status == 401 || status == 403
          ? PhotoIdentificationFailure.unauthenticated
          : status == 429 ? PhotoIdentificationFailure.rateLimited
          : status == 400 || status == 413 ? PhotoIdentificationFailure.invalidPhoto
          : body.contains('Species not found') &&
              (body.contains('404') || status == 422)
          ? PhotoIdentificationFailure.noMatch
          : status == 404 ? PhotoIdentificationFailure.backendNotReady
          : PhotoIdentificationFailure.unavailable,
    };
    final index = payload?['photoIndex'];
    return PhotoIdentificationException(failure,
      photoIndex: index is int && index >= 0 ? index : null);
  }

  /// Applies server suggestions with local alias mapping as a fallback.
  SpeciesSuggestion enrichSuggestion(SpeciesSuggestion suggestion) {
    final matched = TreeSpeciesAliases.matchDropdownLabel(
      scientificName: suggestion.scientificName,
      commonNames: suggestion.commonNames,
    );
    return SpeciesSuggestion(
      scientificName: suggestion.scientificName,
      commonNames: suggestion.commonNames,
      confidence: suggestion.confidence,
      matchedDropdownLabel: suggestion.matchedDropdownLabel != TreeSpeciesAliases.othersLabel
          ? suggestion.matchedDropdownLabel
          : matched,
    );
  }
}
