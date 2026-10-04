import 'package:flutter/material.dart';

import '../../core/constants/tree_species_aliases.dart';
import '../../models/species_identification_result.dart';
import '../../models/user_model.dart';
import '../../models/report_location.dart';
import '../../models/photo_identification_error.dart';

enum PermitAction { cutting, trimming, others }

/// Identifiers for every uploadable attachment on the form.
enum PermitAttachment {
  requestLetter,
  lguCertification,
  landTitle,
  treePhotos,
  contextPhotos,
  ptaCertification,
}

/// Holds all inputs of the tree-cutting permit form so the step widgets can
/// stay small and stateless.
class TreeCuttingFormModel extends ChangeNotifier {
  static const String speciesOthers = TreeSpeciesAliases.othersLabel;
  static const String reasonOthers = 'Others (Provide manual reason)';
  static const String countMore = 'More than 5';
  static const String siteSchool = 'school grounds';
  static const String sitePrivate = 'not school grounds';
  static const String authorityLgu = 'lgu';
  static const String authorityDenr = 'denr_cenro';

  static const List<String> treeVariants = [
    'Mahogany',
    'Mango (Mangifera indica)',
    'Gmelina',
    'Acacia',
    'Narra',
    'Ipil-Ipil',
    'Coconut',
    'White Lauan',
    'Guijo',
    'Apitong',
    'Red Lauan',
    'Mayapis',
    'Tindalo',
    'Bolongeta',
    'Malaikmo',
    'Bayanti',
    'Malatanglin',
    speciesOthers,
  ];

  static const List<String> reasons = [
    'Poses structural hazard to house / property',
    'Interference with electric powerlines / utilities',
    'Tree is diseased, dead, or decaying',
    'Obstructing authorized road/infrastructure construction',
    'Agricultural clearing / personal land re-development',
    reasonOthers,
  ];

  static const List<String> countOptions = ['1', '2', '3', '4', '5', countMore];

  // Applicant
  final applicantName = TextEditingController();
  final address = TextEditingController();
  final contactNumber = TextEditingController();
  final email = TextEditingController();

  // Request
  PermitAction action = PermitAction.cutting;
  final othersAction = TextEditingController();
  final kindOfTree = TextEditingController();
  final numberOfTrees = TextEditingController();
  final reasonForRequest = TextEditingController();
  final remarks = TextEditingController();
  String? selectedSpecies;
  String? selectedCount;
  String? selectedReason;
  SpeciesIdentificationResult? speciesIdentification;

  // Location
  double? latitude;
  double? longitude;
  final barangay = TextEditingController();
  final street = TextEditingController();
  final landmark = TextEditingController();
  final fullAddress = TextEditingController();
  String? siteType;

  // Documents
  String? targetAuthority;
  String? requestLetterUrl;
  String? lguCertificationUrl;
  String? landTitleUrl;
  String? ptaCertificationUrl;
  final List<String> treePhotoUrls = [];
  final List<String> contextPhotoUrls = [];
  final Set<String> validatedTreePhotoUrls = {};
  final Map<String, OnSiteTreeCapture> onSiteTreeCaptures = {};

  /// Tree photos accepted only as on-site evidence (species unconfirmed).
  final Set<String> unverifiedTreePhotoUrls = {};
  TreePhotoValidation? treePhotoValidation;
  String? photoError;

  bool declarationChecked = false;
  bool showDocumentErrors = false;
  PermitAttachment? uploading;
  bool submitting = false;
  bool _prefilled = false;

  bool get isSchoolGrounds => siteType == siteSchool;
  bool get showCustomSpecies => selectedSpecies == speciesOthers;
  bool get showCustomCount => selectedCount == countMore;
  bool get showCustomReason => selectedReason == reasonOthers;
  bool get hasCoordinates => latitude != null && longitude != null;
  bool get requiresSpeciesInspection => unverifiedTreePhotoUrls.isNotEmpty;

  String get actionKey => switch (action) {
    PermitAction.cutting => 'cutting',
    PermitAction.trimming => 'trimming',
    PermitAction.others => 'others',
  };

  /// True once the user has typed or chosen anything beyond the prefill.
  bool get hasUserInput =>
      selectedSpecies != null ||
      selectedCount != null ||
      selectedReason != null ||
      siteType != null ||
      hasCoordinates ||
      targetAuthority != null ||
      requestLetterUrl != null ||
      lguCertificationUrl != null ||
      landTitleUrl != null ||
      ptaCertificationUrl != null ||
      treePhotoUrls.isNotEmpty ||
      contextPhotoUrls.isNotEmpty ||
      remarks.text.trim().isNotEmpty;

  void prefillFrom(UserModel? user) {
    if (_prefilled || user == null) return;
    _prefilled = true;
    if (user.name.isNotEmpty) applicantName.text = user.contextualName;
    final phone = user.phoneNumber?.trim();
    if (phone != null && phone.isNotEmpty) contactNumber.text = phone;
    if (user.email.isNotEmpty) email.text = user.email;
    final addr = user.completeAddress?.trim();
    if (addr != null && addr.isNotEmpty) address.text = addr;
  }

  void setAction(PermitAction value) {
    action = value;
    if (value != PermitAction.others) othersAction.clear();
    notifyListeners();
  }

  void setSpecies(String? value) {
    selectedSpecies = value;
    if (value != speciesOthers) kindOfTree.text = value ?? '';
    notifyListeners();
  }

  void setCount(String? value) {
    selectedCount = value;
    numberOfTrees.text = value == countMore ? '' : (value ?? '');
    notifyListeners();
  }

  void setReason(String? value) {
    selectedReason = value;
    if (value != reasonOthers) reasonForRequest.text = value ?? '';
    notifyListeners();
  }

  void setSiteType(String? value) {
    siteType = value;
    notifyListeners();
  }

  void setAuthority(String? value) {
    targetAuthority = value;
    notifyListeners();
  }

  void setUploading(PermitAttachment? kind) {
    uploading = kind;
    notifyListeners();
  }

  void setSubmitting(bool value) {
    submitting = value;
    notifyListeners();
  }

  bool get busy => uploading != null || submitting;

  void setDeclaration(bool value) {
    declarationChecked = value;
    notifyListeners();
  }

  void applySpeciesSuggestion(SpeciesIdentificationResult result) {
    final suggestion = result.bestMatch;
    if (suggestion == null) return;
    speciesIdentification = result;
    selectedSpecies = suggestion.matchedDropdownLabel;
    kindOfTree.text = showCustomSpecies
        ? TreeSpeciesAliases.formatSpeciesLabel(
            scientificName: suggestion.scientificName,
            commonNames: suggestion.commonNames,
          )
        : suggestion.matchedDropdownLabel;
    notifyListeners();
  }

  void setLocation(ReportLocation result) {
    latitude = result.latitude;
    longitude = result.longitude;
    // On-site photos are checked against the pin, so a moved pin needs a new receipt.
    treePhotoValidation = null;
    fullAddress.text = result.address ?? '';
    barangay.text = result.barangay ?? '';
    street.text = result.street ?? '';
    landmark.text = result.landmark ?? '';
    notifyListeners();
  }

  bool isAttached(PermitAttachment kind) => switch (kind) {
    PermitAttachment.requestLetter => _set(requestLetterUrl),
    PermitAttachment.lguCertification => _set(lguCertificationUrl),
    PermitAttachment.landTitle => _set(landTitleUrl),
    PermitAttachment.treePhotos => treePhotoUrls.isNotEmpty,
    PermitAttachment.contextPhotos => contextPhotoUrls.isNotEmpty,
    PermitAttachment.ptaCertification => _set(ptaCertificationUrl),
  };

  void attach(
    PermitAttachment kind,
    String url, {
    bool photoValidated = false,
    OnSiteTreeCapture? onSiteCapture,
    bool speciesUnverified = false,
  }) {
    switch (kind) {
      case PermitAttachment.requestLetter:
        requestLetterUrl = url;
      case PermitAttachment.lguCertification:
        lguCertificationUrl = url;
      case PermitAttachment.landTitle:
        landTitleUrl = url;
      case PermitAttachment.treePhotos:
        treePhotoValidation = null;
        if (photoValidated) validatedTreePhotoUrls.add(url);
        if (onSiteCapture != null) onSiteTreeCaptures[url] = onSiteCapture;
        if (speciesUnverified) unverifiedTreePhotoUrls.add(url);
        treePhotoUrls.add(url);
      case PermitAttachment.contextPhotos:
        contextPhotoUrls.add(url);
      case PermitAttachment.ptaCertification:
        ptaCertificationUrl = url;
    }
    notifyListeners();
  }

  /// Removes a single-file attachment, or one photo when [index] is given.
  void detach(PermitAttachment kind, {int? index}) {
    switch (kind) {
      case PermitAttachment.requestLetter:
        requestLetterUrl = null;
      case PermitAttachment.lguCertification:
        lguCertificationUrl = null;
      case PermitAttachment.landTitle:
        landTitleUrl = null;
      case PermitAttachment.treePhotos:
        if (index != null) {
          validatedTreePhotoUrls.remove(treePhotoUrls[index]);
          onSiteTreeCaptures.remove(treePhotoUrls[index]);
          unverifiedTreePhotoUrls.remove(treePhotoUrls[index]);
          treePhotoUrls.removeAt(index);
          treePhotoValidation = null;
        }
      case PermitAttachment.contextPhotos:
        if (index != null) contextPhotoUrls.removeAt(index);
      case PermitAttachment.ptaCertification:
        ptaCertificationUrl = null;
    }
    notifyListeners();
  }

  /// Records the server's final per-photo verdict before writing the permit.
  void applyTreePhotoValidation(TreePhotoValidation validation) {
    treePhotoValidation = validation;
    unverifiedTreePhotoUrls
      ..clear()
      ..addAll(validation.unverifiedUrls);
    notifyListeners();
  }

  /// Returns a message describing what is missing on the documents step.
  String? validateDocuments() {
    showDocumentErrors = true;
    notifyListeners();
    if (targetAuthority == null) {
      return 'Choose who will receive your application.';
    }
    if (!_set(requestLetterUrl)) return 'Upload your request letter.';
    if (!_set(lguCertificationUrl)) {
      return 'Upload the LGU / Barangay certification.';
    }
    if (treePhotoUrls.isEmpty) return 'Add at least one photo of the trees.';
    if (!treePhotoUrls.every(validatedTreePhotoUrls.contains)) {
      return 'Replace or validate every tree photo before continuing.';
    }
    if (isSchoolGrounds && !_set(ptaCertificationUrl)) {
      return 'School grounds require a certification from the PTA President.';
    }
    return null;
  }

  String? validateActionType() {
    if (action == PermitAction.others && othersAction.text.trim().isEmpty) {
      return 'Please specify the type of action.';
    }
    return null;
  }

  Map<String, dynamic> toFirestore({
    required String uid,
    required Object submittedAt,
    required Object historyTimestamp,
  }) {
    return {
      'applicationType': actionKey,
      'othersAction': action == PermitAction.others
          ? othersAction.text.trim()
          : null,
      'targetAuthority': targetAuthority,
      'applicantName': applicantName.text.trim(),
      'email': email.text.trim(),
      'contactNumber': contactNumber.text.trim(),
      'address': address.text.trim(),
      'kindOfTree': kindOfTree.text.trim(),
      'numberOfTrees': int.tryParse(numberOfTrees.text.trim()),
      'barangay': barangay.text.trim(),
      'street': street.text.trim(),
      'landmark': landmark.text.trim(),
      'completeAddressDetails': fullAddress.text.trim(),
      'treeLatitude': latitude,
      'treeLongitude': longitude,
      'ptaRequirementBasis': siteType,
      'reasonForRequest': reasonForRequest.text.trim(),
      'remarks': remarks.text.trim(),
      'uploadedPaths': {
        'letterOfRequestPath': requestLetterUrl,
        'barangayClearancePath': lguCertificationUrl,
        'treePicturesPaths': List<String>.of(treePhotoUrls),
        'treeContextPicturesPaths': List<String>.of(contextPhotoUrls),
        'landTitlePath': landTitleUrl,
        'ptaPresidentCertificationPath': ptaCertificationUrl,
      },
      'status': 'pending',
      if (treePhotoValidation != null) ...{
        'treePhotoValidationId': treePhotoValidation!.id,
        'speciesVerification': treePhotoValidation!.speciesVerification,
        if (treePhotoValidation!.requiresInspection) ...{
          'inspectionRequired': true,
          'unverifiedTreePhotoUrls': List<String>.of(
            treePhotoValidation!.unverifiedUrls,
          ),
        },
      },
      'submittedAt': submittedAt,
      'submittedByUid': uid,
      'statusHistory': [
        {
          'status': 'pending',
          'message':
              'Permit application has been successfully submitted and is awaiting review.',
          'updatedAt': historyTimestamp,
        },
      ],
      if (speciesIdentification != null)
        'speciesIdentification': speciesIdentification!.toFirestore(
          userAccepted: true,
        ),
    };
  }

  bool _set(String? url) => url != null && url.trim().isNotEmpty;

  @override
  void dispose() {
    for (final c in [
      applicantName,
      address,
      contactNumber,
      email,
      othersAction,
      kindOfTree,
      numberOfTrees,
      reasonForRequest,
      remarks,
      barangay,
      street,
      landmark,
      fullAddress,
    ]) {
      c.dispose();
    }
    super.dispose();
  }
}
