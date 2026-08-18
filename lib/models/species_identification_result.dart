import '../core/constants/tree_species_aliases.dart';

class SpeciesSuggestion {
  final String scientificName;
  final List<String> commonNames;
  final double confidence;
  final String matchedDropdownLabel;

  const SpeciesSuggestion({
    required this.scientificName,
    required this.commonNames,
    required this.confidence,
    required this.matchedDropdownLabel,
  });

  factory SpeciesSuggestion.fromJson(Map<String, dynamic> json) {
    return SpeciesSuggestion(
      scientificName: (json['scientificName'] as String?) ?? '',
      commonNames: List<String>.from(json['commonNames'] ?? const []),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      matchedDropdownLabel:
          (json['matchedDropdownLabel'] as String?) ??
          TreeSpeciesAliases.othersLabel,
    );
  }

  String get displayName {
    if (commonNames.isNotEmpty) return commonNames.first;
    return scientificName;
  }

  int get confidencePercent => (confidence * 100).round();
}

class SpeciesIdentificationResult {
  final List<SpeciesSuggestion> suggestions;
  final SpeciesSuggestion? bestMatch;
  final List<String> evidencePhotoUrls;
  final DateTime? identifiedAt;

  const SpeciesIdentificationResult({
    required this.suggestions,
    this.bestMatch,
    this.evidencePhotoUrls = const [],
    this.identifiedAt,
  });

  factory SpeciesIdentificationResult.fromJson(Map<String, dynamic> json) {
    final suggestions = (json['suggestions'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => SpeciesSuggestion.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    final best = json['bestMatch'];
    return SpeciesIdentificationResult(
      suggestions: suggestions,
      bestMatch: best is Map
          ? SpeciesSuggestion.fromJson(Map<String, dynamic>.from(best))
          : (suggestions.isNotEmpty ? suggestions.first : null),
      evidencePhotoUrls: List<String>.from(json['evidencePhotoUrls'] ?? const []),
      identifiedAt: json['identifiedAt'] != null
          ? DateTime.tryParse(json['identifiedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toFirestore({
    required bool userAccepted,
  }) {
    final best = bestMatch;
    return {
      'source': 'plantnet',
      if (best != null) ...{
        'suggestedScientificName': best.scientificName,
        'suggestedCommonNames': best.commonNames,
        'confidence': best.confidence,
        'matchedDropdownLabel': best.matchedDropdownLabel,
      },
      'userAccepted': userAccepted,
      'evidencePhotoUrls': evidencePhotoUrls,
      'identifiedAt': (identifiedAt ?? DateTime.now()).toIso8601String(),
    };
  }
}
