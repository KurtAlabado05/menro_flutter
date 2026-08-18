import 'package:cloud_firestore/cloud_firestore.dart';

enum LocationCategory {
  private,
  school,
  highway,
  public,
}

extension LocationCategoryX on LocationCategory {
  String toShortString() {
    return toString().split('.').last;
  }

  String get displayName {
    switch (this) {
      case LocationCategory.private:
        return 'Private';
      case LocationCategory.school:
        return 'School';
      case LocationCategory.highway:
        return 'Highway';
      case LocationCategory.public:
        return 'Public';
    }
  }
}

class TreeCuttingPermitModel {
  final String species;
  final int numberOfTrees;
  final String reasonForCutting;
  final LocationCategory locationCategory;
  final String letterOfRequestPath;
  final String barangayClearancePath;
  final String landTitlePath;
  final List<String> treePicturesPaths;
  final Map<String, dynamic>? speciesIdentification;

  TreeCuttingPermitModel({
    required this.species,
    required this.numberOfTrees,
    required this.reasonForCutting,
    required this.locationCategory,
    required this.letterOfRequestPath,
    required this.barangayClearancePath,
    required this.landTitlePath,
    this.treePicturesPaths = const [],
    this.speciesIdentification,
  });

  factory TreeCuttingPermitModel.fromJson(Map<String, dynamic> json) {
    return TreeCuttingPermitModel(
      species: json['species'] ?? '',
      numberOfTrees: json['numberOfTrees'] ?? 0,
      reasonForCutting: json['reasonForCutting'] ?? '',
      locationCategory: _locationCategoryFromString(
        json['locationCategory']?.toString(),
      ),
      letterOfRequestPath: json['letterOfRequestPath'] ?? '',
      barangayClearancePath: json['barangayClearancePath'] ?? '',
      landTitlePath: json['landTitlePath'] ?? '',
      treePicturesPaths: List<String>.from(json['treePicturesPaths'] ?? []),
      speciesIdentification: json['speciesIdentification'] is Map
          ? Map<String, dynamic>.from(json['speciesIdentification'] as Map)
          : null,
    );
  }

  factory TreeCuttingPermitModel.fromFirestore(
    Map<String, dynamic> json,
    String docId,
  ) {
    return TreeCuttingPermitModel.fromJson(json);
  }

  Map<String, dynamic> toJson() => {
        'species': species,
        'numberOfTrees': numberOfTrees,
        'reasonForCutting': reasonForCutting,
        'locationCategory': locationCategory.toShortString(),
        'letterOfRequestPath': letterOfRequestPath,
        'barangayClearancePath': barangayClearancePath,
        'landTitlePath': landTitlePath,
        'treePicturesPaths': treePicturesPaths,
        if (speciesIdentification != null)
          'speciesIdentification': speciesIdentification,
      };

  Map<String, dynamic> toFirestore() => {
        'species': species,
        'numberOfTrees': numberOfTrees,
        'reasonForCutting': reasonForCutting,
        'locationCategory': locationCategory.toShortString(),
        'letterOfRequestPath': letterOfRequestPath,
        'barangayClearancePath': barangayClearancePath,
        'landTitlePath': landTitlePath,
        'treePicturesPaths': treePicturesPaths,
        if (speciesIdentification != null)
          'speciesIdentification': speciesIdentification,
      };
}

LocationCategory _locationCategoryFromString(String? value) {
  switch (value?.toLowerCase()) {
    case 'private':
      return LocationCategory.private;
    case 'school':
      return LocationCategory.school;
    case 'highway':
      return LocationCategory.highway;
    case 'public':
      return LocationCategory.public;
    default:
      return LocationCategory.private;
  }
}
