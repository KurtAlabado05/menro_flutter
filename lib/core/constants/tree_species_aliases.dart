/// Maps Pl@ntNet scientific/common names to permit dropdown labels.
class TreeSpeciesAliases {
  TreeSpeciesAliases._();

  static const String othersLabel = 'Others (Specify Variant Name)';

  static const Map<String, List<String>> dropdownToAliases = {
    'Mahogany': [
      'swietenia macrophylla',
      'mahogany',
      'big-leaf mahogany',
      'big leaf mahogany',
    ],
    'Mango (Mangifera indica)': ['mangifera indica', 'mango', 'mangga'],
    'Gmelina': ['gmelina arborea', 'gmelina', 'yemane'],
    'Acacia': ['acacia mangium', 'acacia auriculiformis', 'acacia'],
    'Narra': ['pterocarpus indicus', 'narra', 'amboyna'],
    'Ipil-Ipil': [
      'leucaena leucocephala',
      'ipil-ipil',
      'ipil ipil',
      'lead tree',
    ],
    'Coconut': ['cocos nucifera', 'coconut', 'niyog', 'coco palm'],
    'White Lauan': [
      'shorea contorta',
      'pentacme contorta',
      'white lauan',
      'white lauaan',
    ],
    'Guijo': ['shorea guiso', 'guijo', 'red balau', 'red balan'],
    'Apitong': ['dipterocarpus grandiflorus', 'apitong', 'apiton'],
    'Red Lauan': ['shorea negrosensis', 'rubroshorea negrosensis', 'red lauan'],
    // "Mayapis" is applied regionally to two different Dipterocarpaceae
    // genera in the field (Shorea palosapis and Anisoptera thurifera); both
    // scientific-name aliases are listed so either resolves to this label.
    'Mayapis': [
      'shorea palosapis',
      'rubroshorea palosapis',
      'anisoptera thurifera',
      'mayapis',
      'palosapis',
    ],
    'Tindalo': [
      'afzelia rhomboidea',
      'pahudia rhomboidea',
      'intsia rhomboidea',
      'tindalo',
    ],
    'Bolongeta': ['diospyros pilosanthera', 'bolongeta', 'bolong-eta'],
    // Sources disagree on whether "Malaikmo" refers to Celtis philippensis
    // or the congener Celtis luzonica; both are listed as aliases.
    'Malaikmo': [
      'celtis philippensis',
      'celtis luzonica',
      'malaikmo',
      'malaitmo',
    ],
    'Bayanti': ['aglaia rimosa', 'bayanti', 'bayati'],
    'Malatanglin': ['adenanthera pavonina', 'malatanglin'],
  };

  /// Returns the dropdown label that best matches [scientificName] and
  /// [commonNames], or [othersLabel] when no alias matches.
  static String matchDropdownLabel({
    required String scientificName,
    List<String> commonNames = const [],
  }) {
    final haystack = <String>{
      scientificName.toLowerCase().trim(),
      ...commonNames.map((n) => n.toLowerCase().trim()),
    };

    for (final entry in dropdownToAliases.entries) {
      for (final alias in entry.value) {
        if (haystack.any(
          (value) => value.contains(alias) || alias.contains(value),
        )) {
          return entry.key;
        }
      }
    }

    return othersLabel;
  }

  /// Human-readable species label for [kindOfTree] when dropdown is Others.
  static String formatSpeciesLabel({
    required String scientificName,
    List<String> commonNames = const [],
  }) {
    final common = commonNames.isNotEmpty ? commonNames.first : '';
    if (common.isNotEmpty && scientificName.isNotEmpty) {
      return '$common ($scientificName)';
    }
    return scientificName.isNotEmpty ? scientificName : common;
  }
}
