import 'dart:convert';

import 'package:cenro_application/models/photo_identification_error.dart';
import 'package:cenro_application/models/report_location.dart';
import 'package:cenro_application/screens/tree_cutting/tree_cutting_form_model.dart';
import 'package:cenro_application/services/tree_species_identification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'legacy wrapped PlantNet 404 is actionable and never exposes backend JSON',
    () {
      final failure = TreeSpeciesIdentificationService.failureFromResponse(
        500,
        '{"details":"PlantNet request failed (404): Species not found"}',
      );
      expect(failure.failure, PhotoIdentificationFailure.noMatch);
      expect(failure.message, contains('cannot be submitted'));
      expect(failure.message, isNot(contains('PlantNet')));
      expect(failure.message, isNot(contains('500')));
    },
  );

  test('typed errors distinguish invalid photos from service outages', () {
    for (final (code, expected) in [
      ('no_match', PhotoIdentificationFailure.noMatch),
      ('low_confidence', PhotoIdentificationFailure.lowConfidence),
      ('service_unavailable', PhotoIdentificationFailure.unavailable),
      ('rate_limited', PhotoIdentificationFailure.rateLimited),
      ('invalid_photos', PhotoIdentificationFailure.invalidPhoto),
      ('backend_not_ready', PhotoIdentificationFailure.backendNotReady),
      ('failed-precondition', PhotoIdentificationFailure.backendNotReady),
      (
        'validation_storage_unavailable',
        PhotoIdentificationFailure.storageUnavailable,
      ),
      ('onsite_too_far', PhotoIdentificationFailure.onSiteTooFar),
      ('onsite_gps_unreliable', PhotoIdentificationFailure.onSiteGpsUnreliable),
    ]) {
      final error = TreeSpeciesIdentificationService.failureFromResponse(
        422,
        jsonEncode({'code': code, 'photoIndex': 1}),
      );
      expect(error.failure, expected);
      expect(error.photoIndex, 1);
    }
    expect(
      TreeSpeciesIdentificationService.failureFromResponse(
        404,
        'Endpoint not found',
      ).failure,
      PhotoIdentificationFailure.backendNotReady,
    );
  });

  test('backend failures do not blame the photo or phone connection', () {
    const failure = PhotoIdentificationException(
      PhotoIdentificationFailure.storageUnavailable,
    );
    expect(failure.message, contains('server could not save'));
    expect(failure.message, isNot(contains('Check your connection')));
    expect(failure.toString(), contains('storageUnavailable'));
  });

  test(
    'low confidence explains uncertainty without claiming poor photo quality',
    () {
      const failure = PhotoIdentificationException(
        PhotoIdentificationFailure.lowConfidence,
      );
      expect(failure.title, 'Plant identification uncertain');
      expect(failure.message, contains('A clear photo can still'));
      expect(failure.message, isNot(contains('not clear enough')));
    },
  );

  test('empty recognition is rejected rather than successful', () async {
    final service = TreeSpeciesIdentificationService(
      tokenProvider: () async => 'test-token',
      client: MockClient((_) async => http.Response('{"suggestions":[]}', 200)),
    );
    await expectLater(
      service.identifyFromUrls(evidencePhotoUrls: ['photo']),
      throwsA(
        isA<PhotoIdentificationException>().having(
          (e) => e.failure,
          'failure',
          PhotoIdentificationFailure.noMatch,
        ),
      ),
    );
  });

  test(
    'validation receipt must match exact photo list and be unexpired',
    () async {
      const photos = [
        'https://res.cloudinary.com/test/image/upload/v1/tree.jpg',
      ];
      for (final body in [
        {
          'validationId': 'id',
          'evidencePhotoUrls': ['different'],
          'expiresAt': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        },
        {
          'validationId': 'id',
          'evidencePhotoUrls': photos,
          'expiresAt': '2000-01-01T00:00:00Z',
        },
        {'evidencePhotoUrls': photos},
      ]) {
        final service = TreeSpeciesIdentificationService(
          tokenProvider: () async => 'token',
          client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
        );
        await expectLater(
          service.validateTreePhotos(photos),
          throwsA(isA<PhotoIdentificationException>()),
        );
      }
    },
  );

  test(
    'valid receipt and authorization reach correct validation endpoint',
    () async {
      const photos = [
        'https://res.cloudinary.com/test/image/upload/v1/tree.jpg',
      ];
      final service = TreeSpeciesIdentificationService(
        tokenProvider: () async => 'test-token',
        client: MockClient((request) async {
          expect(request.url.path, endsWith('/validateTreePhotos'));
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(jsonDecode(request.body)['imageUrls'], photos);
          return http.Response(
            jsonEncode({
              'validationId': 'trusted-id',
              'evidencePhotoUrls': photos,
              'expiresAt': DateTime.now()
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
            }),
            200,
          );
        }),
      );
      expect((await service.validateTreePhotos(photos)).id, 'trusted-id');
    },
  );

  group('on-site unverified species', () {
    const photos = ['https://res.cloudinary.com/test/image/upload/v1/a.jpg'];
    final capture = OnSiteTreeCapture(
      url: photos.first,
      latitude: 14.954,
      longitude: 120.899,
      accuracyMeters: 9,
      capturedAt: DateTime.utc(2026, 1, 1),
    );
    Map<String, dynamic> receipt(Map<String, dynamic> extra) => {
      'validationId': 'id',
      'evidencePhotoUrls': photos,
      'expiresAt': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      ...extra,
    };

    test(
      'sends captures with the pinned tree and parses flagged photos',
      () async {
        Map<String, dynamic>? sent;
        final service = TreeSpeciesIdentificationService(
          tokenProvider: () async => 'token',
          client: MockClient((request) async {
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode(
                receipt({
                  'speciesVerification': 'unverified_onsite',
                  'unverifiedPhotoIndexes': [0],
                }),
              ),
              200,
            );
          }),
        );
        final result = await service.validateTreePhotos(
          photos,
          onSiteCaptures: [capture],
          treeLatitude: 14.954,
          treeLongitude: 120.899,
        );
        expect(sent?['treeLocation'], {
          'latitude': 14.954,
          'longitude': 120.899,
        });
        expect((sent?['onSiteCaptures'] as List).single, {
          'url': photos.first,
          'latitude': 14.954,
          'longitude': 120.899,
          'accuracyMeters': 9,
          'capturedAt': '2026-01-01T00:00:00.000Z',
        });
        expect(result.requiresInspection, isTrue);
        expect(result.unverifiedUrls, photos);
      },
    );

    test('ordinary validation does not send on-site evidence', () async {
      Map<String, dynamic>? sent;
      final service = TreeSpeciesIdentificationService(
        tokenProvider: () async => 'token',
        client: MockClient((request) async {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(receipt({})), 200);
        }),
      );
      final result = await service.validateTreePhotos(
        photos,
        treeLatitude: 14.954,
        treeLongitude: 120.899,
      );
      expect(sent?.containsKey('onSiteCaptures'), isFalse);
      expect(sent?.containsKey('treeLocation'), isFalse);
      expect(result.requiresInspection, isFalse);
    });

    test('inconsistent receipts are rejected', () async {
      for (final (extra, captures) in [
        (
          {
            'speciesVerification': 'verified',
            'unverifiedPhotoIndexes': [0],
          },
          [capture],
        ),
        (
          {
            'speciesVerification': 'unverified_onsite',
            'unverifiedPhotoIndexes': [0],
          },
          <OnSiteTreeCapture>[],
        ),
      ]) {
        final service = TreeSpeciesIdentificationService(
          tokenProvider: () async => 'token',
          client: MockClient(
            (_) async => http.Response(jsonEncode(receipt(extra)), 200),
          ),
        );
        await expectLater(
          service.validateTreePhotos(
            photos,
            onSiteCaptures: captures,
            treeLatitude: 14.954,
            treeLongitude: 120.899,
          ),
          throwsA(isA<PhotoIdentificationException>()),
        );
      }
    });
  });

  test('manual species selection cannot bypass photo validation', () {
    final model = TreeCuttingFormModel();
    addTearDown(model.dispose);
    model.setAuthority(TreeCuttingFormModel.authorityLgu);
    model.attach(PermitAttachment.requestLetter, 'letter');
    model.attach(PermitAttachment.lguCertification, 'cert');
    model.setSpecies('Narra');
    model.attach(PermitAttachment.treePhotos, 'invalid');
    expect(model.validateDocuments(), contains('validate every tree photo'));
    model.detach(PermitAttachment.treePhotos, index: 0);
    model.attach(PermitAttachment.treePhotos, 'valid', photoValidated: true);
    expect(model.validateDocuments(), isNull);
    model.treePhotoValidation = TreePhotoValidation(
      id: 'receipt',
      urls: ['valid'],
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
    model.attach(PermitAttachment.treePhotos, 'new', photoValidated: true);
    expect(model.treePhotoValidation, isNull);
  });

  test('typed map result populates tree permit location', () {
    final model = TreeCuttingFormModel();
    addTearDown(model.dispose);
    model.setLocation(
      const ReportLocation(
        latitude: 14.95,
        longitude: 120.9,
        address: 'Tree site',
        source: ReportLocationSource.manual,
      ),
    );
    expect(model.latitude, 14.95);
    expect(model.fullAddress.text, 'Tree site');
  });
}
