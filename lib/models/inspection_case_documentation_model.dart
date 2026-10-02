import 'package:cloud_firestore/cloud_firestore.dart';

class InspectionCaseDocumentationModel {
  final String id;
  final String caseType;
  final String title;
  final String findings;
  final int severity;
  final String urgency;
  final String siteAddress;
  final String barangay;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracy;
  final List<Map<String, dynamic>> photos;
  final List<Map<String, String>> files;
  final Map<String, bool> checklistResponses;
  final bool officerAttested;
  final String officerAttestation;
  final DateTime? attestedAt;
  final DateTime? visitScheduledAt;
  final int treeCount;
  final String treeActionType;
  final int seedlingsRequired;
  final int seedlingsPlanted;
  final List<Map<String, dynamic>> activityHistory;
  final String? linkedApplicationId;
  final String? linkedApplicationCollection;
  final String inspectorId;
  final String inspectorName;
  final String status;
  final DateTime recordedAt;

  const InspectionCaseDocumentationModel({
    required this.id,
    required this.caseType,
    required this.title,
    required this.findings,
    required this.severity,
    required this.urgency,
    required this.siteAddress,
    required this.barangay,
    required this.latitude,
    required this.longitude,
    required this.locationAccuracy,
    required this.photos,
    required this.files,
    this.checklistResponses = const {},
    this.officerAttested = false,
    this.officerAttestation = '',
    this.attestedAt,
    this.visitScheduledAt,
    this.treeCount = 0,
    this.treeActionType = 'cutting',
    this.seedlingsRequired = 0,
    this.seedlingsPlanted = 0,
    this.activityHistory = const [],
    required this.linkedApplicationId,
    required this.linkedApplicationCollection,
    required this.inspectorId,
    required this.inspectorName,
    required this.status,
    required this.recordedAt,
  });

  Map<String, dynamic> toFirestore() => {
        'caseType': caseType,
        'title': title,
        'findings': findings,
        'severity': severity,
        'urgency': urgency,
        'siteAddress': siteAddress,
        'barangay': barangay,
        'latitude': latitude,
        'longitude': longitude,
        'locationAccuracy': locationAccuracy,
        'photos': photos,
        'files': files,
        'checklistResponses': checklistResponses,
        'officerAttested': officerAttested,
        'officerAttestation': officerAttestation,
        'attestedAt': attestedAt == null ? null : Timestamp.fromDate(attestedAt!),
        'visitScheduledAt': visitScheduledAt == null
          ? null
          : Timestamp.fromDate(visitScheduledAt!),
        'treeCount': treeCount,
        'treeActionType': treeActionType,
        'seedlingsRequired': seedlingsRequired,
        'seedlingsPlanted': seedlingsPlanted,
        'activityHistory': activityHistory,
        'linkedApplicationId': linkedApplicationId,
        'linkedApplicationCollection': linkedApplicationCollection,
        'inspectorId': inspectorId,
        'inspectorName': inspectorName,
        'status': status,
        'recordedAt': Timestamp.fromDate(recordedAt),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
