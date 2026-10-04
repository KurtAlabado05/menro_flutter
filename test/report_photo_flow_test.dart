import 'dart:async';
import 'dart:typed_data';

import 'package:cenro_application/models/report_location.dart';
import 'package:cenro_application/models/report_model.dart';
import 'package:cenro_application/models/user_model.dart';
import 'package:cenro_application/providers/auth_provider.dart';
import 'package:cenro_application/providers/report_provider.dart';
import 'package:cenro_application/screens/report/report_screen.dart';
import 'package:cenro_application/services/geo/report_location_resolver.dart';
import 'package:cenro_application/services/location/device_location_service.dart';
import 'package:cenro_application/services/media/photo_metadata_service.dart';
import 'package:cenro_application/services/media/report_photo_upload_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'support/report_camera_fakes.dart';

class FakeAuth extends ChangeNotifier implements AuthProvider {
  FakeAuth([this.account]);
  final UserModel? account;
  @override
  UserModel? get user => account;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeReports extends ChangeNotifier implements ReportProvider {
  ReportModel? nearby;
  final List<ReportModel> submitted = [];
  int lookupCount = 0;
  bool failSubmission = false;
  @override
  bool get isLoading => false;
  @override
  Future<ReportModel?> findNearbyActiveReport(ReportModel report) async {
    lookupCount++;
    return nearby;
  }

  @override
  Future<ReportModel> submitReport(ReportModel report) async {
    if (failSubmission) throw StateError('Firestore unavailable');
    submitted.add(report);
    return report;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeGps extends DeviceLocationService {
  FakeGps(this.fix);
  final Future<LocationFix> fix;
  @override
  Future<LocationAvailability> checkAvailability({
    bool requestPermission = true,
  }) async => LocationAvailability.available;
  @override
  Future<LocationFix?> lastKnown({
    Duration maxAge = const Duration(minutes: 2),
  }) async => null;
  @override
  Future<LocationFix> currentFix({
    Duration timeout = const Duration(seconds: 12),
  }) => fix;
}

class FakeResolver extends ReportLocationResolver {
  @override
  Future<ReportLocation?> resolve({
    required double latitude,
    required double longitude,
    required ReportLocationSource source,
    double? accuracyMeters,
    DateTime? capturedAt,
  }) async => ReportLocation(
    latitude: latitude,
    longitude: longitude,
    source: source,
    accuracyMeters: accuracyMeters,
    barangay: 'Poblacion',
    address: source == ReportLocationSource.photoExif
        ? 'Photo address'
        : 'GPS address',
  );
}

class FakePicker extends ImagePicker {
  ImageSource? source;
  bool? fullMetadata;
  double? width;
  int? quality;
  bool cancel = false;
  LostDataResponse? recovery;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    fullMetadata = requestFullMetadata;
    width = maxWidth;
    quality = imageQuality;
    return cancel
        ? null
        : XFile.fromData(image.encodeJpg(image.Image(width: 8, height: 8)));
  }

  @override
  Future<LostDataResponse> retrieveLostData() async =>
      recovery ?? LostDataResponse.empty();
}

class FakeMetadata extends PhotoMetadataService {
  const FakeMetadata(this.metadata);
  final PhotoMetadata metadata;
  @override
  Future<PreparedReportPhoto> prepare(Uint8List original) async =>
      PreparedReportPhoto(
        bytes: image.encodeJpg(image.Image(width: 8, height: 8)),
        metadata: metadata,
      );
}

void main() {
  LocationFix fix({double accuracy = 12}) => LocationFix(
    latitude: 14.9545,
    longitude: 120.8995,
    accuracyMeters: accuracy,
    timestamp: DateTime.now(),
  );

  Future<GlobalKey<NavigatorState>> mount(
    WidgetTester tester, {
    required FakeGps gps,
    required FakePicker picker,
    FakeReportCameraService? camera,
    PhotoMetadata metadata = const PhotoMetadata(),
    ReportPhotoUploader? uploader,
    FakeReports? reportProvider,
    UserModel? account,
  }) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final auth = FakeAuth(account);
    final reports = reportProvider ?? FakeReports();
    addTearDown(auth.dispose);
    addTearDown(reports.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ReportProvider>.value(value: reports),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: ReportScreen(
            deviceLocation: gps,
            locationResolver: FakeResolver(),
            imagePicker: picker,
            cameraService:
                camera ??
                FakeReportCameraService(
                  bytes: image.encodeJpg(image.Image(width: 8, height: 8)),
                ),
            photoMetadata: FakeMetadata(metadata),
            photoUploader:
                uploader ?? (bytes, name) async => 'https://example.com/$name',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return navigatorKey;
  }

  testWidgets('Snap & Report opens live camera instead of the file picker', (
    tester,
  ) async {
    final picker = FakePicker();
    await mount(tester, gps: FakeGps(Future.value(fix())), picker: picker);
    await tester.tap(find.text('Snap & Report'));
    await tester.pumpAndSettle();
    expect(find.text('Live webcam preview'), findsOneWidget);
    expect(picker.source, isNull);
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(picker.source, isNull);
    await tester.ensureVisible(find.text('Incident Location'));
    expect(find.textContaining('From camera GPS'), findsOneWidget);
  });

  testWidgets('gallery GPS fills incident address and source', (tester) async {
    final picker = FakePicker();
    await mount(
      tester,
      gps: FakeGps(Future.value(fix())),
      picker: picker,
      metadata: const PhotoMetadata(latitude: 14.955, longitude: 120.899),
    );
    await tester.tap(find.text('Upload from gallery'));
    await tester.pumpAndSettle();
    expect(picker.source, ImageSource.gallery);
    expect(picker.fullMetadata, isTrue);
    expect(picker.width, isNull);
    expect(picker.quality, isNull);
    expect(find.text('Photo address'), findsOneWidget);
    expect(find.textContaining('From photo location'), findsOneWidget);
  });

  testWidgets('camera cancellation keeps the selected location', (
    tester,
  ) async {
    final picker = FakePicker();
    await mount(tester, gps: FakeGps(Future.value(fix())), picker: picker);
    await tester.tap(find.text('Snap & Report'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(picker.source, isNull);
    expect(find.text('GPS address'), findsOneWidget);
    expect(find.text('Snap & Report'), findsOneWidget);
  });

  testWidgets('Add Photo camera option also opens live preview', (
    tester,
  ) async {
    final picker = FakePicker();
    await mount(tester, gps: FakeGps(Future.value(fix())), picker: picker);
    await tester.ensureVisible(find.text('Add Photo'));
    await tester.tap(find.text('Add Photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Take a Photo'));
    await tester.pumpAndSettle();
    expect(find.text('Live webcam preview'), findsOneWidget);
    expect(picker.source, isNull);
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(find.text('Uploaded'), findsOneWidget);
    expect(picker.source, isNull);
  });

  testWidgets(
    'gallery without GPS keeps device location and explains fallback',
    (tester) async {
      await mount(
        tester,
        gps: FakeGps(Future.value(fix())),
        picker: FakePicker(),
      );
      await tester.tap(find.text('Upload from gallery'));
      await tester.pumpAndSettle();
      expect(find.text('GPS address'), findsOneWidget);
      expect(find.textContaining('photo has no saved GPS'), findsOneWidget);
      expect(find.textContaining('From photo location'), findsNothing);
    },
  );

  testWidgets(
    'older photo location requires confirmation without blocking attachment',
    (tester) async {
      await mount(
        tester,
        gps: FakeGps(Future.value(fix())),
        picker: FakePicker(),
        metadata: PhotoMetadata(
          latitude: 14.955,
          longitude: 120.899,
          takenAt: DateTime.now().subtract(const Duration(hours: 49)),
        ),
      );
      await tester.tap(find.text('Upload from gallery'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Use the photo location?'), findsOneWidget);
      await tester.tap(find.text('Keep current location'));
      await tester.pumpAndSettle();
      expect(find.text('GPS address'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    },
  );

  testWidgets('recovers Android camera evidence after process restart', (
    tester,
  ) async {
    final picker = FakePicker()
      ..recovery = LostDataResponse(
        files: [
          XFile.fromData(image.encodeJpg(image.Image(width: 8, height: 8))),
        ],
        type: RetrieveType.image,
      );
    await mount(tester, gps: FakeGps(Future.value(fix())), picker: picker);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('Recovered photos'), findsOneWidget);
  });

  testWidgets('manual map pin wins over late GPS and photo metadata', (
    tester,
  ) async {
    final gps = Completer<LocationFix>();
    final picker = FakePicker();
    final navigator = await mount(
      tester,
      gps: FakeGps(gps.future),
      picker: picker,
      metadata: const PhotoMetadata(latitude: 14.955, longitude: 120.899),
    );
    await tester.ensureVisible(find.text('Pick on map'));
    await tester.tap(find.text('Pick on map'));
    navigator.currentState!.pop(
      const ReportLocation(
        latitude: 14.954,
        longitude: 120.899,
        address: 'Manual incident',
        barangay: 'Poblacion',
        source: ReportLocationSource.manual,
      ),
    );
    await tester.pumpAndSettle();
    gps.complete(fix());
    await tester.pumpAndSettle();
    expect(find.text('Manual incident'), findsOneWidget);
    await tester.ensureVisible(find.text('Upload from gallery'));
    await tester.tap(find.text('Upload from gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Manual incident'), findsOneWidget);
    expect(find.text('Photo address'), findsNothing);
    expect(find.text('Picked on map'), findsOneWidget);
  });

  testWidgets('poor GPS cannot be used as the incident location', (
    tester,
  ) async {
    await mount(
      tester,
      gps: FakeGps(Future.value(fix(accuracy: 151))),
      picker: FakePicker(),
    );
    await tester.pumpAndSettle();
    expect(find.text('GPS address'), findsNothing);
    expect(find.textContaining('GPS accuracy is too low'), findsOneWidget);
    expect(find.text('Location not set yet'), findsOneWidget);
  });

  testWidgets('upload starts before submission and failure can be retried', (
    tester,
  ) async {
    var calls = 0;
    await mount(
      tester,
      gps: FakeGps(Future.value(fix())),
      picker: FakePicker(),
      uploader: (_, _) async {
        if (++calls == 1) throw StateError('Offline');
        return 'https://example.com/retried.jpg';
      },
    );
    await tester.tap(find.text('Snap & Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Retry photo 1'), findsOneWidget);
    await tester.tap(find.text('Retry photo 1'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Uploaded'), findsOneWidget);
    expect(find.text('Report submitted successfully!'), findsNothing);
  });

  testWidgets('nearby match is displayed before typing report details', (
    tester,
  ) async {
    final reports = FakeReports()
      ..nearby = ReportModel(
        id: 'nearby',
        title: 'Existing dumping report',
        description: 'Waste',
        category: 'Illegal Dumping of Solid Waste',
        location: 'Poblacion',
        latitude: 14.9545,
        longitude: 120.8995,
        submittedBy: 'citizen',
        submittedByName: 'Citizen',
        submittedAt: DateTime.now(),
      );
    await mount(
      tester,
      gps: FakeGps(Future.value(fix())),
      picker: FakePicker(),
      reportProvider: reports,
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Existing dumping report'), findsOneWidget);
    expect(find.text('Similar report 0 m away'), findsOneWidget);
    expect(find.text('Me Too'), findsOneWidget);
    expect(reports.lookupCount, 1);
  });

  testWidgets(
    'submission waits for pending upload and reuses the completed URL',
    (tester) async {
      final pending = Completer<String>();
      var uploadCount = 0;
      final reports = FakeReports()..failSubmission = true;
      await mount(
        tester,
        gps: FakeGps(Future.value(fix())),
        picker: FakePicker(),
        reportProvider: reports,
        account: UserModel(
          id: 'citizen',
          name: 'Citizen',
          email: 'citizen@example.com',
          role: 'citizen',
          phoneNumber: '09123456789',
          joinedAt: DateTime.now(),
        ),
        uploader: (_, _) {
          uploadCount++;
          return pending.future;
        },
      );
      await tester.tap(find.text('Snap & Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.ensureVisible(fields.at(0));
      await tester.enterText(fields.at(0), 'Dumped rubbish');
      await tester.ensureVisible(fields.at(1));
      await tester.enterText(
        fields.at(1),
        'Several bags dumped beside the road.',
      );
      await tester.ensureVisible(find.text('Submit Report'));
      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(reports.submitted, isEmpty);
      expect(uploadCount, 1);
      pending.complete('https://example.com/completed.jpg');
      await tester.pumpAndSettle();
      expect(reports.submitted, isEmpty);
      expect(
        find.textContaining('Could not submit your report'),
        findsOneWidget,
      );
      expect(find.text('Uploaded'), findsOneWidget);
      reports.failSubmission = false;
      await tester.ensureVisible(find.text('Submit Report'));
      await tester.tap(find.text('Submit Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(reports.submitted.single.imageUrls, [
        'https://example.com/completed.jpg',
      ]);
      expect(uploadCount, 1);
      expect(reports.lookupCount, greaterThanOrEqualTo(2));
    },
  );
}
