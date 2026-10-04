import 'dart:async';
import 'dart:typed_data';

import 'package:cenro_application/models/photo_identification_error.dart';
import 'package:cenro_application/models/report_location.dart';
import 'package:cenro_application/models/species_identification_result.dart';
import 'package:cenro_application/models/user_model.dart';
import 'package:cenro_application/providers/auth_provider.dart';
import 'package:cenro_application/screens/tree_cutting/tree_cutting_form_model.dart';
import 'package:cenro_application/screens/tree_cutting_application_screen.dart';
import 'package:cenro_application/services/cloudinary_image_service.dart';
import 'package:cenro_application/services/location/device_location_service.dart';
import 'package:cenro_application/services/tree_species_identification_service.dart';
import 'package:cenro_application/widgets/tree_species_identify_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  UserModel? get user => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Picker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile.fromData(image.encodeJpg(image.Image(width: 8, height: 8)));
}

class _Uploads extends CloudinaryImageService {
  _Uploads() : super(cloudName: 'test', uploadPreset: 'test');
  int count = 0;
  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    Duration? timeout,
  }) async =>
      'https://res.cloudinary.com/test/image/upload/v1/photo${++count}.jpg';
}

class _Identification extends TreeSpeciesIdentificationService {
  final calls = <List<String>>[];
  Object? failure;
  int? failAt;
  double confidence = 0.8;
  Future<void>? pending;
  static const suggestion = SpeciesSuggestion(
    scientificName: 'Pterocarpus indicus',
    commonNames: ['Narra'],
    confidence: 0.8,
    matchedDropdownLabel: 'Narra',
  );
  @override
  Future<SpeciesIdentificationResult> identifyFromUrls({
    required List<String> evidencePhotoUrls,
    List<String> organs = const [],
  }) async {
    calls.add(evidencePhotoUrls);
    if (pending != null) await pending!;
    if (failure != null && (failAt == null || calls.length == failAt)) {
      throw failure!;
    }
    final best = SpeciesSuggestion(
      scientificName: suggestion.scientificName,
      commonNames: ['Narra'],
      confidence: confidence,
      matchedDropdownLabel: 'Narra',
    );
    return SpeciesIdentificationResult(suggestions: [best], bestMatch: best);
  }

  final onSiteCalls = <List<OnSiteTreeCapture>>[];
  final locations = <(double?, double?)>[];

  /// Simulates a leafless tree: recognition is uncertain for every photo,
  /// so only photos with on-site captures are accepted (as unverified).
  bool leafless = false;

  @override
  Future<TreePhotoValidation> validateTreePhotos(
    List<String> urls, {
    List<OnSiteTreeCapture> onSiteCaptures = const [],
    double? treeLatitude,
    double? treeLongitude,
  }) async {
    calls.add(List.of(urls));
    onSiteCalls.add(List.of(onSiteCaptures));
    locations.add((treeLatitude, treeLongitude));
    if (pending != null) await pending!;
    if (failure != null && (failAt == null || calls.length == failAt)) {
      throw failure!;
    }
    final unverified = <String>[];
    if (leafless) {
      final onSite = onSiteCaptures.map((c) => c.url).toSet();
      for (var i = 0; i < urls.length; i++) {
        if (!onSite.contains(urls[i])) {
          throw PhotoIdentificationException(
            PhotoIdentificationFailure.lowConfidence,
            photoIndex: i,
          );
        }
        unverified.add(urls[i]);
      }
    }
    return TreePhotoValidation(
      id: 'server-receipt',
      urls: urls,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      speciesVerification: unverified.isEmpty
          ? TreePhotoValidation.verified
          : TreePhotoValidation.unverifiedOnSite,
      unverifiedUrls: unverified,
    );
  }
}

void main() {
  Future<void> mountSheet(WidgetTester tester, _Identification service) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TreeSpeciesIdentifySheet(
            cloudinary: _Uploads(),
            identificationService: service,
            imagePicker: _Picker(),
          ),
        ),
      ),
    );
  }

  Future<void> addGallery(WidgetTester tester, {int index = 0}) async {
    final upload = find.text('Upload').at(index);
    await tester.ensureVisible(upload);
    await tester.tap(upload);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'non-plant photo shows safe actionable UI with no manual bypass',
    (tester) async {
      final service = _Identification()
        ..failure = const PhotoIdentificationException(
          PhotoIdentificationFailure.noMatch,
        );
      await mountSheet(tester, service);
      await addGallery(tester);
      await tester.tap(find.text('Analyze photos'));
      await tester.pumpAndSettle();
      expect(find.text('Photo could not be recognized'), findsOneWidget);
      expect(find.textContaining('cannot be submitted'), findsOneWidget);
      expect(find.textContaining('select species manually'), findsNothing);
      expect(find.text('Use this species'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a valid photo cannot mask a second invalid photo', (
    tester,
  ) async {
    final service = _Identification()
      ..failAt = 2
      ..failure = const PhotoIdentificationException(
        PhotoIdentificationFailure.noMatch,
      );
    await mountSheet(tester, service);
    await addGallery(tester);
    await addGallery(tester);
    await tester.tap(find.text('Analyze photos'));
    await tester.pumpAndSettle();
    expect(service.calls.length, 2);
    expect(service.calls.every((urls) => urls.length == 1), isTrue);
    expect(find.textContaining('Photo 2:'), findsOneWidget);
    expect(find.text('Use this species'), findsNothing);
    service.failure = null;
    await tester.tap(find.text('Analyze photos'));
    await tester.pumpAndSettle();
    expect(find.text('Use this species'), findsOneWidget);
  });

  testWidgets('low-confidence photos cannot be accepted', (tester) async {
    final service = _Identification()..confidence = 0.49;
    await mountSheet(tester, service);
    await addGallery(tester);
    await tester.tap(find.text('Analyze photos'));
    await tester.pumpAndSettle();
    expect(find.text('Plant identification uncertain'), findsOneWidget);
    expect(find.text('Use this species'), findsNothing);
  });

  testWidgets('a single recognized photo succeeds; more are optional', (
    tester,
  ) async {
    final service = _Identification();
    await mountSheet(tester, service);
    expect(find.text('No photo added yet'), findsOneWidget);
    expect(find.textContaining('A single photo is enough'), findsOneWidget);
    await addGallery(tester);
    await tester.tap(find.text('Analyze photos'));
    await tester.pumpAndSettle();
    expect(service.calls.length, 1);
    expect(service.calls.single.length, 1);
    expect(find.text('Use this species'), findsOneWidget);
  });

  testWidgets(
    'photo mutation and duplicate analysis are blocked while analyzing',
    (tester) async {
      final ready = Completer<void>();
      final service = _Identification()..pending = ready.future;
      await mountSheet(tester, service);
      await addGallery(tester);
      await tester.tap(find.text('Analyze photos'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Analyzing plant...'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.cancel), warnIfMissed: false);
      expect(find.textContaining('not yet checked'), findsOneWidget);
      ready.complete();
      await tester.pumpAndSettle();
      expect(service.calls.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  TreeCuttingFormModel validModel() {
    final model = TreeCuttingFormModel();
    model.applicantName.text = 'Applicant';
    model.address.text = 'Baliwag';
    model.contactNumber.text = '09123456789';
    model.email.text = 'applicant@example.com';
    model.setSpecies('Narra');
    model.setCount('1');
    model.setReason(TreeCuttingFormModel.reasons.first);
    model.latitude = 14.954;
    model.longitude = 120.899;
    model.setSiteType(TreeCuttingFormModel.sitePrivate);
    model.setAuthority(TreeCuttingFormModel.authorityLgu);
    model.attach(PermitAttachment.requestLetter, 'letter');
    model.attach(PermitAttachment.lguCertification, 'cert');
    model.attach(
      PermitAttachment.treePhotos,
      'https://res.cloudinary.com/test/image/upload/v1/tree.jpg',
      photoValidated: true,
    );
    model.setDeclaration(true);
    return model;
  }

  Future<void> mountApplication(
    WidgetTester tester,
    TreeCuttingFormModel model,
    _Identification service,
    Future<void> Function(Map<String, dynamic>) submit, {
    Future<LocationFix> Function()? onSiteLocation,
  }) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TreeCuttingApplicationScreen(
                      model: model,
                      identificationService: service,
                      currentUid: () => 'citizen',
                      submitApplication: submit,
                      imagePicker: _Picker(),
                      cloudinary: _Uploads(),
                      captureOnSitePhoto: (_) async => XFile.fromData(
                        image.encodeJpg(image.Image(width: 8, height: 8)),
                        name: 'onsite.jpg',
                      ),
                      onSiteLocation:
                          onSiteLocation ??
                          () async => LocationFix(
                            latitude: 14.9541,
                            longitude: 120.8991,
                            accuracyMeters: 8,
                            timestamp: DateTime.now(),
                          ),
                    ),
                  ),
                ),
                child: const Text('Open application'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open application'));
    await tester.pumpAndSettle();
  }

  Future<void> review(WidgetTester tester) async {
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Submit Application'), findsOneWidget);
  }

  testWidgets(
    'successful submission validates exact photos then exits without navigation lock',
    (tester) async {
      final model = validModel();
      addTearDown(model.dispose);
      final service = _Identification();
      Map<String, dynamic>? submitted;
      await mountApplication(
        tester,
        model,
        service,
        (data) async => submitted = data,
      );
      await review(tester);
      await tester.tap(find.text('Submit Application'));
      await tester.pumpAndSettle();
      expect(submitted?['treePhotoValidationId'], 'server-receipt');
      expect(service.calls.single, model.treePhotoUrls);
      expect(find.text('Open application'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'final photo validation outage prevents write and preserves retryable draft',
    (tester) async {
      final model = validModel();
      addTearDown(model.dispose);
      final service = _Identification()
        ..failure = const PhotoIdentificationException(
          PhotoIdentificationFailure.unavailable,
        );
      var writes = 0;
      await mountApplication(tester, model, service, (_) async {
        writes++;
      });
      await review(tester);
      await tester.tap(find.text('Submit Application'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(model.treePhotoUrls.length, 1);
      expect(model.submitting, isFalse);
      expect(
        find.textContaining('cannot be submitted until validation succeeds'),
        findsWidgets,
      );
      service.failure = null;
      await tester.tap(find.text('Submit Application'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty exit and confirmed discard do not recursively pop', (
    tester,
  ) async {
    final empty = TreeCuttingFormModel();
    addTearDown(empty.dispose);
    await mountApplication(tester, empty, _Identification(), (_) async {});
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open application'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final dirty = validModel();
    addTearDown(dirty.dispose);
    await mountApplication(tester, dirty, _Identification(), (_) async {});
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Open application'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invalid second tree attachment is rejected without losing first photo',
    (tester) async {
      final model = validModel();
      addTearDown(model.dispose);
      final original = model.treePhotoUrls.single;
      final service = _Identification()
        ..failure = const PhotoIdentificationException(
          PhotoIdentificationFailure.noMatch,
        );
      await mountApplication(tester, model, service, (_) async {});
      for (var step = 0; step < 2; step++) {
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }
      final add = find.text('Add photo').first;
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();
      expect(model.treePhotoUrls, [original]);
      expect(model.photoError, contains('cannot be submitted'));
      expect(model.busy, isFalse);
      expect(service.calls.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('back navigation is blocked while final validation is running', (
    tester,
  ) async {
    final ready = Completer<void>();
    final model = validModel();
    addTearDown(model.dispose);
    final service = _Identification()..pending = ready.future;
    var writes = 0;
    await mountApplication(tester, model, service, (_) async {
      writes++;
    });
    await review(tester);
    await tester.tap(find.text('Submit Application'));
    await tester.pump();
    await tester.pageBack();
    await tester.pump();
    expect(model.submitting, isTrue);
    expect(find.text('Discard application?'), findsNothing);
    expect(find.text('Tree Permit Application'), findsOneWidget);
    expect(writes, 0);
    ready.complete();
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Open application'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> openDocuments(WidgetTester tester) async {
    for (var step = 0; step < 2; step++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'leafless tree: failed photo offers on-site capture and submission is flagged for inspection',
    (tester) async {
      final model = validModel()..detach(PermitAttachment.treePhotos, index: 0);
      addTearDown(model.dispose);
      final service = _Identification()..leafless = true;
      Map<String, dynamic>? submitted;
      await mountApplication(
        tester,
        model,
        service,
        (data) async => submitted = data,
      );
      await openDocuments(tester);
      final add = find.text('Add photo').first;
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();
      expect(model.treePhotoUrls, isEmpty);
      expect(find.text('Tree has no leaves or is dead?'), findsOneWidget);

      await tester.tap(find.text('Take on-site photo'));
      await tester.pumpAndSettle();
      expect(model.treePhotoUrls.length, 1);
      expect(model.unverifiedTreePhotoUrls, model.treePhotoUrls.toSet());
      expect(service.onSiteCalls.last.single.accuracyMeters, 8);
      expect(service.locations.last, (14.954, 120.899));
      expect(find.text('On-site'), findsOneWidget);
      expect(
        find.textContaining('flagged so MENRO can verify'),
        findsOneWidget,
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('verified at the site inspection'),
        findsOneWidget,
      );
      await tester.tap(find.text('Submit Application'));
      await tester.pumpAndSettle();
      expect(service.onSiteCalls.last.single.url, model.treePhotoUrls.single);
      expect(submitted?['speciesVerification'], 'unverified_onsite');
      expect(submitted?['inspectionRequired'], isTrue);
      expect(submitted?['unverifiedTreePhotoUrls'], model.treePhotoUrls);
      expect(submitted?['treeLatitude'], 14.954);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (name, fix, expected) in [
    (
      'too far from pinned tree',
      LocationFix(
        latitude: 14.97,
        longitude: 120.899,
        accuracyMeters: 5,
        timestamp: DateTime.now(),
      ),
      'too far from the tree you pinned',
    ),
    (
      'inaccurate GPS',
      LocationFix(
        latitude: 14.954,
        longitude: 120.899,
        accuracyMeters: 120,
        timestamp: DateTime.now(),
      ),
      'not accurate enough',
    ),
  ]) {
    testWidgets('on-site photo is rejected before upload when $name', (
      tester,
    ) async {
      final model = validModel();
      addTearDown(model.dispose);
      final service = _Identification();
      await mountApplication(
        tester,
        model,
        service,
        (_) async {},
        onSiteLocation: () async => fix,
      );
      await openDocuments(tester);
      final button = find.text('No leaves or dead tree? Take on-site photo');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(model.treePhotoUrls.length, 1);
      expect(model.unverifiedTreePhotoUrls, isEmpty);
      expect(service.calls, isEmpty);
      expect(model.photoError, contains(expected));
      expect(model.busy, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  test(
    'on-site state is cleared with its photo and a moved pin needs a new receipt',
    () {
      final model = validModel();
      addTearDown(model.dispose);
      final capture = OnSiteTreeCapture(
        url: 'onsite',
        latitude: 14.954,
        longitude: 120.899,
        accuracyMeters: 5,
        capturedAt: DateTime.now(),
      );
      model.attach(
        PermitAttachment.treePhotos,
        'onsite',
        photoValidated: true,
        onSiteCapture: capture,
        speciesUnverified: true,
      );
      model.treePhotoValidation = TreePhotoValidation(
        id: 'r',
        urls: List.of(model.treePhotoUrls),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(model.requiresSpeciesInspection, isTrue);
      model.setLocation(const ReportLocation(latitude: 15, longitude: 121));
      expect(model.treePhotoValidation, isNull);
      model.detach(PermitAttachment.treePhotos, index: 1);
      expect(model.onSiteTreeCaptures, isEmpty);
      expect(model.requiresSpeciesInspection, isFalse);
    },
  );
}
