import 'package:cenro_application/core/constants/status_config.dart';
import 'package:cenro_application/core/constants/user_roles.dart';
import 'package:cenro_application/models/inspection_application_model.dart';
import 'package:cenro_application/models/inspection_case_documentation_model.dart';
import 'package:cenro_application/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inspection officer role is recognized as staff', () {
    final user = UserModel.fromFirestore({
      'role': 'inspection_officer',
    }, 'inspection-uid');

    expect(UserRoles.isStaff(user.role), isTrue);
    expect(user.isStaff, isTrue);
    expect(user.isInspectionOfficer, isTrue);
  });

  test('non-staff roles are not classified as staff', () {
    expect(UserRoles.isStaff('citizen'), isFalse);
    expect(UserRoles.isStaff('organization'), isFalse);
    expect(UserRoles.isStaff(null), isFalse);
  });

  test('inspection application reads tree permit fields and document URLs', () {
    final application = InspectionApplicationModel.fromFirestore(
      {
        'applicantName': 'Sam Rivera',
        'email': 'sam@example.test',
        'species': 'Narra',
        'numberOfTrees': 2,
        'treePicturesPaths': ['https://example.test/tree.jpg'],
        'letterOfRequestPath': 'https://example.test/request.pdf',
      },
      'permit-1',
      'tree_cutting_permits',
    );

    expect(application.applicantName, 'Sam Rivera');
    expect(application.applicantEmail, 'sam@example.test');
    expect(application.kindOfTree, 'Narra');
    expect(application.documents, hasLength(2));
    expect(application.buildFindings().numberOfTrees, '2');
  });

  test(
    'inspection queue model reads environmental report details and photos',
    () {
      final report = InspectionApplicationModel.fromFirestore(
        {
          'title': 'Illegal dumping',
          'description': 'Waste was left beside the creek.',
          'category': 'Water Pollution',
          'location': 'Poblacion',
          'submittedByName': 'Sam Rivera',
          'imageUrls': ['https://example.test/evidence.jpg'],
          'status': 'pending',
        },
        'report-1',
        'reports',
      );

      expect(report.type, 'environmental_report');
      expect(report.category, 'Water Pollution');
      expect(report.description, 'Waste was left beside the creek.');
      expect(report.applicantName, 'Sam Rivera');
      expect(report.applicationAddress, 'Poblacion');
      expect(report.documents.single.url, 'https://example.test/evidence.jpg');
    },
  );

  test(
    'seedling count is three per tree for cutting and zero for trimming',
    () {
      const cutting = InspectionFindings(
        numberOfTrees: '4',
        actionType: 'cutting',
      );
      const trimming = InspectionFindings(
        numberOfTrees: '4',
        actionType: 'trimming',
      );
      const invalidCount = InspectionFindings(numberOfTrees: 'unknown');

      expect(cutting.seedlingsRequired, 12);
      expect(trimming.seedlingsRequired, 0);
      expect(invalidCount.seedlingsRequired, 0);
    },
  );

  test('forwarded inspection status has the expected label', () {
    expect(
      StatusConfig.getLabel('forwarded_to_inspection_officer'),
      'Under Inspection',
    );
    expect(
      StatusConfig.getLabel('forwarded_to_denr_officer'),
      'For DENR Review',
    );
  });

  test('case documentation serialization preserves field-work evidence', () {
    final record = InspectionCaseDocumentationModel(
      id: 'case-1',
      caseType: 'tree_cutting_inspection',
      title: 'Narra inspection',
      findings: 'Tree is near the power line.',
      severity: 3,
      urgency: 'urgent',
      siteAddress: 'Baliwag',
      barangay: 'Poblacion',
      latitude: 14.95,
      longitude: 120.9,
      locationAccuracy: 4,
      photos: const [
        {
          'name': 'before.jpg',
          'url': 'https://example.test/before.jpg',
          'phase': 'before',
          'caption': 'Tree tag 07',
          'measurementCm': 34.5,
          'annotationPoint': {'x': 0.4, 'y': 0.6},
        },
        {
          'name': 'after.jpg',
          'url': 'https://example.test/after.jpg',
          'phase': 'after',
        },
      ],
      files: const [],
      checklistResponses: const {'Tree condition recorded': true},
      officerAttested: true,
      officerAttestation: 'Officer Example',
      attestedAt: DateTime.utc(2026, 9, 30),
      visitScheduledAt: DateTime.utc(2026, 10, 1, 9),
      treeCount: 2,
      treeActionType: 'cutting',
      seedlingsRequired: 6,
      activityHistory: const [
        {'event': 'case_submitted', 'actorId': 'inspection-uid'},
      ],
      linkedApplicationId: 'permit-1',
      linkedApplicationCollection: 'tree_cutting_permits',
      inspectorId: 'inspection-uid',
      inspectorName: 'Officer Example',
      status: 'submitted',
      recordedAt: DateTime.utc(2026, 9, 30),
    );

    final data = record.toFirestore();
    expect(data['checklistResponses'], {'Tree condition recorded': true});
    expect(data['officerAttested'], isTrue);
    expect(data['visitScheduledAt'], isNotNull);
    expect(data['seedlingsRequired'], 6);
    expect((data['photos'] as List).map((photo) => photo['phase']), [
      'before',
      'after',
    ]);
    expect(data['activityHistory'], hasLength(1));
  });
}
