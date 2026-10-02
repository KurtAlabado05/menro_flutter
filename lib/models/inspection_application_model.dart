import 'package:cloud_firestore/cloud_firestore.dart';

/// A single supporting document/photo attached to an application or permit.
class InspectionDocument {
  final String name;
  final String url;
  final bool verified;
  final String kind;

  const InspectionDocument({
    required this.name,
    required this.url,
    this.verified = false,
    this.kind = 'document',
  });

  factory InspectionDocument.fromMap(Map<String, dynamic> map) {
    return InspectionDocument(
      name: (map['name'] ?? map['filename'] ?? map['title'] ?? '').toString(),
      url: (map['url'] ?? map['downloadUrl'] ?? map['fileUrl'] ?? '')
          .toString(),
      verified: map['verified'] == true,
      kind: (map['kind'] ?? 'document').toString(),
    );
  }
}

/// Inspection findings fields, mirrors the web admin's inspection form shape
/// (`buildInspectionFormFromApplication` in InspectionOfficerPage.jsx).
class InspectionFindings {
  final String applicantName;
  final String email;
  final String contactNumber;
  final String address;
  final String applicationType;
  final String kindOfTree;
  final String locationOfTrees;
  final String numberOfTrees;
  final String reasonForRequest;
  final String ptaRequirementBasis;
  final bool legalCertificationChecked;
  final String inspectionDate;
  final String scenarioReason;
  final String actionType;

  const InspectionFindings({
    this.applicantName = '',
    this.email = '',
    this.contactNumber = '',
    this.address = '',
    this.applicationType = '',
    this.kindOfTree = '',
    this.locationOfTrees = '',
    this.numberOfTrees = '',
    this.reasonForRequest = '',
    this.ptaRequirementBasis = '',
    this.legalCertificationChecked = false,
    this.inspectionDate = '',
    this.scenarioReason = '',
    this.actionType = 'cutting',
  });

  InspectionFindings copyWith({
    String? inspectionDate,
    String? scenarioReason,
    String? numberOfTrees,
    String? locationOfTrees,
    String? actionType,
  }) {
    return InspectionFindings(
      applicantName: applicantName,
      email: email,
      contactNumber: contactNumber,
      address: address,
      applicationType: applicationType,
      kindOfTree: kindOfTree,
      locationOfTrees: locationOfTrees ?? this.locationOfTrees,
      numberOfTrees: numberOfTrees ?? this.numberOfTrees,
      reasonForRequest: reasonForRequest,
      ptaRequirementBasis: ptaRequirementBasis,
      legalCertificationChecked: legalCertificationChecked,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      scenarioReason: scenarioReason ?? this.scenarioReason,
      actionType: actionType ?? this.actionType,
    );
  }

  /// Trees cut require 3 seedlings each; trimming requires none.
  int get seedlingsRequired {
    final trees = int.tryParse(numberOfTrees) ?? 0;
    if (trees <= 0) return 0;
    return actionType == 'cutting' ? trees * 3 : 0;
  }
}

/// A merged inspection queue item from applications, permits, or reports.
class InspectionApplicationModel {
  final String id;
  final String sourceCollection;
  final String applicantName;
  final String applicantEmail;
  final String applicantUid;
  final String type;
  final String applicationType;
  final String applicationAddress;
  final String description;
  final String category;
  final String kindOfTree;
  final String locationOfTrees;
  final String status;
  final String forwardedToRole;
  final bool requirementsComplete;
  final DateTime? submittedAt;
  final List<InspectionDocument> documents;
  final Map<String, dynamic> raw;

  const InspectionApplicationModel({
    required this.id,
    required this.sourceCollection,
    required this.applicantName,
    required this.applicantEmail,
    required this.applicantUid,
    required this.type,
    required this.applicationType,
    required this.applicationAddress,
    required this.description,
    required this.category,
    required this.kindOfTree,
    required this.locationOfTrees,
    required this.status,
    required this.forwardedToRole,
    required this.requirementsComplete,
    required this.submittedAt,
    required this.documents,
    required this.raw,
  });

  factory InspectionApplicationModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
    String sourceCollection,
  ) {
    final isReport = sourceCollection == 'reports';
    final rawType =
        (data['type'] ??
                data['applicationType'] ??
                data['serviceName'] ??
                data['category'] ??
                data['charterServiceCode'] ??
                '')
            .toString();
    final isTreePermit =
        !isReport &&
        (sourceCollection == 'tree_cutting_permits' ||
            rawType.toLowerCase().contains('tree') ||
            (data['applicationType']?.toString().toLowerCase() == 'cutting'));

    final normalizedStatus =
        (data['status'] ?? (isTreePermit ? 'submitted' : 'received'))
            .toString()
            .trim()
            .toLowerCase();
    final isVerifiedStatus =
        normalizedStatus == 'verified' ||
        normalizedStatus == 'requirements_complete';
    final explicitRequirementsComplete = data['requirementsComplete'] == true;
    final requirementsComplete =
        explicitRequirementsComplete || isVerifiedStatus;

    return InspectionApplicationModel(
      id: id,
      sourceCollection: sourceCollection,
      applicantName:
          (data['applicantName'] ??
                  data['name'] ??
                  (isReport ? data['submittedByName'] : null) ??
                  '')
              .toString(),
      applicantEmail: (data['applicantEmail'] ?? data['email'] ?? '')
          .toString(),
      applicantUid: (data['applicantUid'] ?? data['uid'] ?? '').toString(),
      type: isReport
          ? 'environmental_report'
          : isTreePermit
          ? 'tree_cutting_permit'
          : rawType,
      applicationType:
          (data['applicationType'] ??
                  data['type'] ??
                  (isReport ? data['category'] : null) ??
                  '')
              .toString(),
      applicationAddress:
          (data['applicationAddress'] ??
                  data['address'] ??
                  (isReport ? data['location'] : null) ??
                  '')
              .toString(),
      description: (data['description'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      kindOfTree: (data['kindOfTree'] ?? data['species'] ?? '').toString(),
      locationOfTrees: (data['locationOfTrees'] ?? '').toString(),
      status: (data['status'] ?? (isTreePermit ? 'submitted' : 'received'))
          .toString(),
      forwardedToRole: (data['forwardedToRole'] ?? '').toString(),
      requirementsComplete: requirementsComplete,
      submittedAt: _parseDate(data['submittedAt'] ?? data['createdAt']),
      documents: _buildDocuments(
        data,
        isTreePermit,
        requirementsComplete,
        isReport: isReport,
      ),
      raw: data,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static List<InspectionDocument> _buildDocuments(
    Map<String, dynamic> data,
    bool isTreePermit,
    bool forceVerified, {
    bool isReport = false,
  }) {
    if (isReport) {
      final urls = <String>{
        if ((data['imageUrl'] ?? '').toString().trim().isNotEmpty)
          data['imageUrl'].toString().trim(),
        if (data['imageUrls'] is List)
          ...(data['imageUrls'] as List)
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty),
      };
      return urls
          .map(
            (url) => InspectionDocument(
              name: 'Report evidence',
              url: url,
              kind: 'report-photo',
            ),
          )
          .toList();
    }
    if (!isTreePermit) {
      final docsRaw = data['documents'];
      if (docsRaw is List) {
        return docsRaw
            .whereType<Map>()
            .map(
              (m) => InspectionDocument.fromMap(Map<String, dynamic>.from(m)),
            )
            .where((d) => d.name.isNotEmpty || d.url.isNotEmpty)
            .toList();
      }
      return const [];
    }

    final docs = <InspectionDocument>[];
    void pushDoc(String name, Object? url, {String kind = 'document'}) {
      final normalizedUrl = (url ?? '').toString().trim();
      if (normalizedUrl.isEmpty) return;
      docs.add(
        InspectionDocument(
          name: name,
          url: normalizedUrl,
          verified: forceVerified || normalizedUrl != 'PENDING_UPLOAD',
          kind: kind,
        ),
      );
    }

    pushDoc('Letter of Request', data['letterOfRequestPath']);
    pushDoc('Barangay Clearance', data['barangayClearancePath']);
    pushDoc('Land Title', data['landTitlePath']);
    pushDoc(
      'PTA President Certification',
      data['ptaPresidentCertificationPath'],
    );

    final pictures = <String>{};
    for (final key in [
      'treePicturesPaths',
      'treePicturesPath',
      'treePicturePath',
      'treePhotoPath',
      'treePhotosPath',
      'treePhotosPaths',
    ]) {
      final value = data[key];
      if (value is List) {
        for (final item in value) {
          final text = item?.toString().trim() ?? '';
          if (text.isNotEmpty) pictures.add(text);
        }
      } else if (value is String && value.trim().isNotEmpty) {
        pictures.addAll(
          value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
        );
      }
    }
    var pictureIndex = 1;
    for (final url in pictures) {
      pushDoc('Tree Picture $pictureIndex', url, kind: 'tree-picture');
      pictureIndex++;
    }

    final customDocs = data['documents'];
    if (customDocs is List) {
      var customIndex = 1;
      for (final item in customDocs.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        pushDoc(
          (map['name'] ?? 'Additional Document $customIndex').toString(),
          map['url'],
          kind: (map['kind'] ?? 'document').toString(),
        );
        customIndex++;
      }
    }

    return docs;
  }

  /// Builds the editable inspection findings form, reading the same
  /// fallback field chains as the web admin's `buildInspectionFormFromApplication`.
  InspectionFindings buildFindings() {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = raw[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    final dateValue = pick([
      'inspectionDate',
      'inspectionScheduledDate',
      'inspectionScheduledAt',
      'inspectionCompletedAt',
    ]);
    final treesValue = pick([
      'inspectionNumberOfTrees',
      'numberOfTrees',
      'treeCount',
      'noOfTrees',
      'treesCount',
    ]);
    final actionTypeValue = pick([
      'inspectionActionType',
      'actionType',
      'treeAction',
    ]);

    return InspectionFindings(
      applicantName: applicantName,
      email: applicantEmail.isNotEmpty
          ? applicantEmail
          : pick(['email', 'submittedByEmail']),
      contactNumber: pick(['contactNumber']),
      address: applicationAddress,
      applicationType: applicationType,
      kindOfTree: kindOfTree,
      locationOfTrees: locationOfTrees.isNotEmpty
          ? locationOfTrees
          : pick([
              'inspectionLocationOfTrees',
              'treeLocation',
              'inspectionSite',
            ]),
      numberOfTrees: treesValue,
      reasonForRequest: pick(['reasonForRequest']),
      ptaRequirementBasis: pick(['ptaRequirementBasis']),
      legalCertificationChecked: raw['legalCertificationChecked'] == true,
      inspectionDate: dateValue,
      scenarioReason: pick([
        'inspectionScenarioReason',
        'inspectionNotes',
        'reason',
        'remarks',
        'remarksOfInspection',
      ]),
      actionType: actionTypeValue.isEmpty ? 'cutting' : actionTypeValue,
    );
  }
}
