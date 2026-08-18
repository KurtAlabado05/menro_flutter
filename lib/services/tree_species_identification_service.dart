import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/constants/api_config.dart';
import '../core/constants/tree_species_aliases.dart';
import '../models/species_identification_result.dart';

class TreeSpeciesIdentificationService {
  const TreeSpeciesIdentificationService();

  static const double lowConfidenceThreshold = 0.5;

  Future<SpeciesIdentificationResult> identifyFromUrls({
    required List<String> evidencePhotoUrls,
    List<String> organs = const [],
  }) async {
    if (evidencePhotoUrls.isEmpty) {
      throw Exception('At least one photo is required for identification.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to identify tree species.');
    }

    final idToken = await user.getIdToken();

    final response = await http.post(
      Uri.parse(ApiConfig.identifySpeciesUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'imageUrls': evidencePhotoUrls,
        if (organs.isNotEmpty) 'organs': organs,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body;
      throw Exception(
        'Species identification failed (${response.statusCode}): $body',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final result = SpeciesIdentificationResult.fromJson(decoded);
    return SpeciesIdentificationResult(
      suggestions: result.suggestions,
      bestMatch: result.bestMatch,
      evidencePhotoUrls: evidencePhotoUrls,
      identifiedAt: result.identifiedAt ?? DateTime.now(),
    );
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
