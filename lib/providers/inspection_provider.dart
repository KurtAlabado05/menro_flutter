import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/inspection_application_model.dart';
import '../models/inspection_case_documentation_model.dart';
import '../models/user_model.dart';

/// Streams the same Firestore collections the web admin's Inspection Officer
/// module reads (`applications` + `tree_cutting_permits`) and exposes the
/// write actions used by that workflow (save findings, forward to DENR,
/// confirm & email, resolve).
class InspectionProvider extends ChangeNotifier {
  final FirebaseFirestore _db;

  InspectionProvider({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _appsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _permitsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reportsSub;

  List<InspectionApplicationModel> _applications = [];
  List<InspectionApplicationModel> _permits = [];
  List<InspectionApplicationModel> _reports = [];

  bool _isLoading = true;
  String? _error;
  bool _appsFromCache = false;
  bool _permitsFromCache = false;
  bool _reportsFromCache = false;
  bool _appsHavePendingWrites = false;
  bool _permitsHavePendingWrites = false;
  bool _reportsHavePendingWrites = false;
  bool _hasAppsSnapshot = false;
  bool _hasPermitsSnapshot = false;
  bool _hasReportsSnapshot = false;
  bool _queueBaselineInitialized = false;
  final Set<String> _previousQueueKeys = {};

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUsingCachedData =>
      _appsFromCache || _permitsFromCache || _reportsFromCache;
  bool get hasPendingWrites =>
      _appsHavePendingWrites ||
      _permitsHavePendingWrites ||
      _reportsHavePendingWrites;

  /// Applications forwarded to (or currently owned by) the Inspection Officer,
  /// filtered/sorted the same way as the web admin's `queue` memo.
  List<InspectionApplicationModel> get queue {
    final all = [..._applications, ..._permits, ..._reports];
    final filtered = all.where((a) {
      final status = a.status.trim().toLowerCase();
      if (a.sourceCollection == 'reports') {
        return !{
          'resolved',
          'completed',
          'closed',
          'archived',
          'rejected',
          'forwarded_to_denr',
          'forwarded_to_denr_officer',
        }.contains(status);
      }
      final forwardedMatch =
          status == 'forwarded_to_inspection_officer' ||
          status == 'inspection_in_progress' ||
          status == 'approved_by_denr';
      final roleMatch = a.forwardedToRole == 'inspection_officer';
      return forwardedMatch || roleMatch;
    }).toList();

    filtered.sort((x, y) {
      final xDate = x.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final yDate = y.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return yDate.compareTo(xDate);
    });
    return filtered;
  }

  /// Starts the real-time listeners. Call once (e.g. in the queue screen's
  /// initState) and call [dispose]/stop when the shell is torn down.
  void start() {
    _isLoading = true;
    _error = null;
    _appsFromCache = false;
    _permitsFromCache = false;
    _reportsFromCache = false;
    _appsHavePendingWrites = false;
    _permitsHavePendingWrites = false;
    _reportsHavePendingWrites = false;
    _hasAppsSnapshot = false;
    _hasPermitsSnapshot = false;
    _hasReportsSnapshot = false;
    _queueBaselineInitialized = false;
    _previousQueueKeys.clear();
    notifyListeners();

    _appsSub?.cancel();
    _permitsSub?.cancel();
    _reportsSub?.cancel();

    _appsSub = _db
        .collection('applications')
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snap) {
            _applications = snap.docs
                .map(
                  (d) => InspectionApplicationModel.fromFirestore(
                    d.data(),
                    d.id,
                    'applications',
                  ),
                )
                .toList();
            _appsFromCache = snap.metadata.isFromCache;
            _appsHavePendingWrites = snap.metadata.hasPendingWrites;
            _hasAppsSnapshot = true;
            _isLoading = false;
            _error = null;
            _syncQueueNotifications();
            notifyListeners();
          },
          onError: (Object e) {
            _error = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );

    _permitsSub = _db
        .collection('tree_cutting_permits')
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snap) {
            _permits = snap.docs
                .map(
                  (d) => InspectionApplicationModel.fromFirestore(
                    d.data(),
                    d.id,
                    'tree_cutting_permits',
                  ),
                )
                .toList();
            _permitsFromCache = snap.metadata.isFromCache;
            _permitsHavePendingWrites = snap.metadata.hasPendingWrites;
            _hasPermitsSnapshot = true;
            _isLoading = false;
            _error = null;
            _syncQueueNotifications();
            notifyListeners();
          },
          onError: (Object e) {
            _error = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );

    _reportsSub = _db
        .collection('reports')
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snap) {
            _reports = snap.docs
                .map(
                  (d) => InspectionApplicationModel.fromFirestore(
                    d.data(),
                    d.id,
                    'reports',
                  ),
                )
                .toList();
            _reportsFromCache = snap.metadata.isFromCache;
            _reportsHavePendingWrites = snap.metadata.hasPendingWrites;
            _hasReportsSnapshot = true;
            _isLoading = false;
            _error = null;
            _syncQueueNotifications();
            notifyListeners();
          },
          onError: (Object e) {
            _error = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  void _syncQueueNotifications() {
    if (!_hasAppsSnapshot || !_hasPermitsSnapshot || !_hasReportsSnapshot) {
      return;
    }
    final currentQueue = queue;
    final currentKeys = currentQueue
        .map(
          (application) => '${application.sourceCollection}:${application.id}',
        )
        .toSet();

    if (!_queueBaselineInitialized) {
      _previousQueueKeys
        ..clear()
        ..addAll(currentKeys);
      _queueBaselineInitialized = true;
      return;
    }

    for (final application in currentQueue) {
      final key = '${application.sourceCollection}:${application.id}';
      if (!_previousQueueKeys.contains(key)) {
        unawaited(_createAssignmentNotification(application));
      }
    }

    _previousQueueKeys
      ..clear()
      ..addAll(currentKeys);
  }

  Future<void> _createAssignmentNotification(
    InspectionApplicationModel application,
  ) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final profile = await _db.collection('users').doc(uid).get();
      if (profile.data()?['allowNotifications'] == false) return;

      final applicant = application.applicantName.isEmpty
          ? 'An applicant'
          : application.applicantName;
      final applicationType = application.applicationType.isNotEmpty
          ? application.applicationType
          : application.type;
      await _db.collection('notifications').add({
        'userId': uid,
        'title': 'New inspection assignment',
        'body': '$applicant · $applicationType',
        'type': 'system',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'relatedId': application.id,
        'relatedCollection': application.sourceCollection,
      });
    } catch (e) {
      debugPrint('⚠️ inspection assignment notification failed: $e');
    }
  }

  @override
  void dispose() {
    _appsSub?.cancel();
    _permitsSub?.cancel();
    _reportsSub?.cancel();
    super.dispose();
  }

  /// Cancels the live listeners without disposing the provider itself, so a
  /// staff session can stop reads on logout while the app keeps running.
  void stop() {
    _appsSub?.cancel();
    _permitsSub?.cancel();
    _reportsSub?.cancel();
    _appsSub = null;
    _permitsSub = null;
    _reportsSub = null;
    _applications = [];
    _permits = [];
    _reports = [];
    _isLoading = true;
    _error = null;
  }

  Map<String, dynamic> _updatedByFrom(UserModel actingUser) => {
    'id': actingUser.id,
    'role': actingUser.role,
    'name': actingUser.contextualName,
  };

  Map<String, dynamic> _statusHistoryEntry({
    required String message,
    required String status,
    required UserModel actingUser,
  }) {
    return {
      'message': message,
      'status': status,
      'timestamp': DateTime.now().toIso8601String(),
      'updatedBy': _updatedByFrom(actingUser),
    };
  }

  Future<void> _updateDoc(
    InspectionApplicationModel application,
    Map<String, dynamic> patch,
  ) async {
    await _db
        .collection(application.sourceCollection)
        .doc(application.id)
        .update({...patch, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> _createAuditLogBestEffort({
    required String action,
    required String details,
    String targetType = 'application',
    String? targetId,
    String? targetName,
    String? targetEmail,
  }) async {
    try {
      final current = FirebaseAuth.instance.currentUser;
      await _db.collection('audit_logs').add({
        'adminUid': current?.uid,
        'adminName': current?.displayName ?? current?.email ?? 'Unknown',
        'adminEmail': current?.email,
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'targetName': targetName,
        'targetEmail': targetEmail,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ audit log write failed: $e');
    }
  }

  Future<String> saveCaseDocumentation(
    InspectionCaseDocumentationModel documentation,
  ) async {
    final reference = _db
        .collection('case_documentation')
        .doc(documentation.id);
    await reference.set(documentation.toFirestore());

    await _createAuditLogBestEffort(
      action: 'INSPECTION_CASE_DOCUMENTATION_SAVED',
      details:
          '${documentation.status} ${documentation.caseType} case documentation',
      targetType: 'inspection_case',
      targetId: documentation.id,
      targetName: documentation.title,
    );

    return reference.id;
  }

  Future<void> updateCaseDocumentation(
    InspectionCaseDocumentationModel documentation,
  ) async {
    await _db
        .collection('case_documentation')
        .doc(documentation.id)
        .set(documentation.toFirestore(), SetOptions(merge: true));

    await _createAuditLogBestEffort(
      action: 'INSPECTION_CASE_DOCUMENTATION_UPDATED',
      details: '${documentation.status} case documentation updated',
      targetType: 'inspection_case',
      targetId: documentation.id,
      targetName: documentation.title,
    );
  }

  Future<void> forwardCaseDocumentationToDenr({
    required String caseId,
    required Map<String, dynamic> caseData,
    required UserModel actingUser,
  }) async {
    if (caseData['status'] != 'submitted') {
      throw Exception('Only submitted case documentation can be forwarded.');
    }
    final sourceId = caseData['linkedApplicationId']?.toString() ?? '';
    final sourceCollection =
        caseData['linkedApplicationCollection']?.toString() ?? '';
    if (sourceId.isEmpty ||
        !{
          'applications',
          'tree_cutting_permits',
          'reports',
        }.contains(sourceCollection)) {
      throw Exception(
        'Link a tree-cutting application or environmental report first.',
      );
    }

    final now = DateTime.now().toIso8601String();
    final caseReference = _db.collection('case_documentation').doc(caseId);
    final batch = _db.batch();
    batch.update(caseReference, {
      'status': 'forwarded_to_denr_officer',
      'forwardedToRole': 'denr_officer',
      'forwardedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'activityHistory': FieldValue.arrayUnion([
        {
          'event': 'case_forwarded_to_denr',
          'actorId': actingUser.id,
          'actorName': actingUser.contextualName,
          'at': now,
        },
      ]),
    });

    final sourceReference = _db.collection(sourceCollection).doc(sourceId);
    if (sourceCollection == 'reports') {
      batch.update(sourceReference, {
        'status': 'forwarded_to_denr_officer',
        'forwardedToRole': 'denr_officer',
        'forwardedAt': FieldValue.serverTimestamp(),
        'inspectionNotes': caseData['findings'],
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status': 'forwarded_to_denr_officer',
            'message':
                'Inspection case documentation forwarded to DENR Officer.',
            'timestamp': now,
            'updatedBy': actingUser.contextualName,
          },
        ]),
      });
    } else {
      batch.update(sourceReference, {
        'status': 'forwarded_to_denr_officer',
        'forwardedToRole': 'denr_officer',
        'forwardedToDenrAt': now,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          _statusHistoryEntry(
            message: 'Inspection case documentation forwarded to DENR Officer.',
            status: 'forwarded_to_denr_officer',
            actingUser: actingUser,
          ),
        ]),
      });
    }

    await batch.commit();
    await _createAuditLogBestEffort(
      action: 'INSPECTION_CASE_FORWARDED_TO_DENR',
      details:
          'Case documentation and linked source forwarded to DENR Officer.',
      targetType: 'inspection_case',
      targetId: caseId,
      targetName: caseData['title']?.toString(),
    );
  }

  Future<String> addSeedlingFollowUp({
    required String caseId,
    required String caseTitle,
    required UserModel actingUser,
    required int seedlingsPlanted,
    required DateTime visitDate,
    required String notes,
  }) async {
    final parentReference = _db.collection('case_documentation').doc(caseId);
    final reference = parentReference.collection('seedling_followups').doc();
    final batch = _db.batch();
    batch.set(reference, {
      'caseId': caseId,
      'caseTitle': caseTitle,
      'inspectorId': actingUser.id,
      'inspectorName': actingUser.contextualName,
      'seedlingsPlanted': seedlingsPlanted,
      'visitDate': Timestamp.fromDate(visitDate),
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(parentReference, {
      'seedlingsPlanted': FieldValue.increment(seedlingsPlanted),
      'lastSeedlingFollowUpId': reference.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    await _createAuditLogBestEffort(
      action: 'INSPECTION_SEEDLING_FOLLOWUP_ADDED',
      details: '$seedlingsPlanted seedlings recorded for $caseTitle',
      targetType: 'inspection_case',
      targetId: caseId,
      targetName: caseTitle,
    );
    return reference.id;
  }

  Future<String> saveTreeIdentification(
    Map<String, dynamic> identification,
  ) async {
    final reference = _db.collection('inspection_tree_identifications').doc();
    await reference.set({
      ...identification,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _createAuditLogBestEffort(
      action: 'INSPECTION_TREE_IDENTIFICATION_SAVED',
      details: 'Tree species identification saved by Inspection Officer',
      targetType: 'tree_identification',
      targetId: reference.id,
      targetName: identification['matchedDropdownLabel']?.toString(),
    );

    return reference.id;
  }

  /// Saves inspection findings (date, action type, tree count, location,
  /// scenario) and marks the application `inspection_in_progress`.
  Future<void> saveFindings({
    required InspectionApplicationModel application,
    required InspectionFindings findings,
    required UserModel actingUser,
  }) async {
    await _updateDoc(application, {
      'inspectionDate': findings.inspectionDate.isEmpty
          ? null
          : findings.inspectionDate,
      'inspectionScenarioReason': findings.scenarioReason,
      'inspectionNumberOfTrees': int.tryParse(findings.numberOfTrees) ?? 0,
      'inspectionLocationOfTrees': findings.locationOfTrees,
      'inspectionActionType': findings.actionType.isEmpty
          ? 'cutting'
          : findings.actionType,
      'inspectionNotes': findings.scenarioReason,
      'seedlingsRequired': findings.seedlingsRequired,
      'status': 'inspection_in_progress',
      'statusHistory': FieldValue.arrayUnion([
        _statusHistoryEntry(
          message: 'Inspection findings saved (inspection in progress).',
          status: 'inspection_in_progress',
          actingUser: actingUser,
        ),
      ]),
    });

    await _createAuditLogBestEffort(
      action: 'APPLICATION_INSPECTION_FINDINGS_SAVED',
      details: 'Inspection findings saved',
      targetId: application.id,
      targetName: application.type,
      targetEmail: application.applicantEmail,
    );
  }

  /// Forwards the application to the DENR Officer.
  Future<void> forwardToDenr({
    required InspectionApplicationModel application,
    required InspectionFindings findings,
    required UserModel actingUser,
  }) async {
    final now = DateTime.now().toIso8601String();
    final findingsUnlocked =
        application.status.trim().toLowerCase() == 'approved_by_denr';
    await _updateDoc(application, {
      if (findingsUnlocked && findings.inspectionDate.isNotEmpty)
        'inspectionDate': findings.inspectionDate,
      if (findingsUnlocked && findings.scenarioReason.trim().isNotEmpty)
        'inspectionScenarioReason': findings.scenarioReason,
      if (findingsUnlocked && findings.numberOfTrees.isNotEmpty)
        'inspectionNumberOfTrees': int.tryParse(findings.numberOfTrees) ?? 0,
      if (findingsUnlocked && findings.locationOfTrees.isNotEmpty)
        'inspectionLocationOfTrees': findings.locationOfTrees,
      if (findingsUnlocked)
        'inspectionActionType': findings.actionType.isEmpty
            ? 'cutting'
            : findings.actionType,
      if (findingsUnlocked && findings.scenarioReason.trim().isNotEmpty)
        'inspectionNotes': findings.scenarioReason,
      if (findingsUnlocked) 'seedlingsRequired': findings.seedlingsRequired,
      'status': 'forwarded_to_denr_officer',
      'inspectionCompletedAt': now,
      'forwardedToRole': 'denr_officer',
      'forwardedToDenrAt': now,
      'statusHistory': FieldValue.arrayUnion([
        _statusHistoryEntry(
          message: 'Forwarded to DENR Officer',
          status: 'forwarded_to_denr_officer',
          actingUser: actingUser,
        ),
      ]),
    });

    await _createAuditLogBestEffort(
      action: 'APPLICATION_FORWARD_DENR',
      details:
          'Inspection forwarded to DENR Officer. Inspection findings can be completed after DENR approval.',
      targetId: application.id,
      targetName: application.type,
      targetEmail: application.applicantEmail,
    );
  }

  /// Confirms the inspection date and queues a notification email to the
  /// applicant via the `email_outbox` collection.
  Future<void> confirmInspectionAndSendEmail({
    required InspectionApplicationModel application,
    required InspectionFindings findings,
    required UserModel actingUser,
  }) async {
    if (findings.inspectionDate.isEmpty) {
      throw Exception('Set inspection date before confirming.');
    }
    if (application.applicantEmail.isEmpty) {
      throw Exception('No recipient email found for this application.');
    }

    final findingsUnlocked =
        application.status.trim().toLowerCase() == 'approved_by_denr';
    await _updateDoc(application, {
      if (findingsUnlocked) 'inspectionDate': findings.inspectionDate,
      if (findingsUnlocked) 'inspectionScenarioReason': findings.scenarioReason,
      if (findingsUnlocked)
        'inspectionNumberOfTrees': int.tryParse(findings.numberOfTrees) ?? 0,
      if (findingsUnlocked)
        'inspectionLocationOfTrees': findings.locationOfTrees,
      if (findingsUnlocked)
        'inspectionActionType': findings.actionType.isEmpty
            ? 'cutting'
            : findings.actionType,
      if (findingsUnlocked) 'inspectionNotes': findings.scenarioReason,
      if (findingsUnlocked) 'seedlingsRequired': findings.seedlingsRequired,
      'status': 'inspection_confirmed',
      'inspectionConfirmedAt': DateTime.now().toIso8601String(),
      'inspectionConfirmedByRole': 'inspection_officer',
    });

    final subject =
        'Inspection date confirmed for ${application.applicantName.isNotEmpty ? application.applicantName : "your permit"}';
    final body = [
      'Good day ${application.applicantName.isNotEmpty ? application.applicantName : "Applicant"},',
      '',
      'Your inspection has been confirmed for ${findings.inspectionDate}.',
      'Application Type: ${application.applicationType.isNotEmpty ? application.applicationType : "Tree Cutting Permit"}',
      'Tree Species: ${application.kindOfTree.isEmpty ? "—" : application.kindOfTree}',
      'Location of Trees: ${findings.locationOfTrees.isEmpty ? "—" : findings.locationOfTrees}',
      'Number of Trees: ${findings.numberOfTrees.isEmpty ? "—" : findings.numberOfTrees}',
      '',
      'Please wait for further instructions from the Inspection Officer and DENR office.',
      '',
      'Regards,',
      'MENRO Portal',
    ].join('\n');

    await _db.collection('email_outbox').add({
      'to': application.applicantEmail,
      'subject': subject,
      'body': body,
      'status': 'pending',
      'templateType': 'inspection_confirmation',
      'relatedType': 'application',
      'relatedId': application.id,
      'recipientName': application.applicantName.isEmpty
          ? null
          : application.applicantName,
      'inspectionDate': findings.inspectionDate,
      'applicationType': application.applicationType.isNotEmpty
          ? application.applicationType
          : application.type,
      'sourceCollection': application.sourceCollection,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _createAuditLogBestEffort(
      action: 'APPLICATION_INSPECTION_CONFIRMED_EMAIL_QUEUED',
      details:
          'Inspection confirmed and email queued for ${findings.inspectionDate}',
      targetId: application.id,
      targetName: application.type,
      targetEmail: application.applicantEmail,
    );
  }

  /// Marks a DENR-approved application as resolved.
  Future<void> resolve({
    required InspectionApplicationModel application,
    required UserModel actingUser,
  }) async {
    await _updateDoc(application, {
      'status': 'resolved',
      'resolvedAt': DateTime.now().toIso8601String(),
      'resolvedByRole': 'inspection_officer',
      'statusHistory': FieldValue.arrayUnion([
        _statusHistoryEntry(
          message: 'Resolved by Inspection Officer.',
          status: 'resolved',
          actingUser: actingUser,
        ),
      ]),
    });

    await _createAuditLogBestEffort(
      action: 'APPLICATION_RESOLVED',
      details: 'Inspection Officer resolved approved permit',
      targetId: application.id,
      targetName: application.type,
      targetEmail: application.applicantEmail,
    );
  }
}
