import 'package:cenro_application/services/media/photo_metadata_service.dart';
import 'package:exif/exif.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

Uint8List photoFixture({bool withGps = true, int orientation = 1}) {
  final photo = image.Image(width: 1600, height: 800);
  photo.exif.imageIfd.orientation = orientation;
  if (withGps) {
    final gps = photo.exif.gpsIfd;
    gps[1] = image.IfdValueAscii('N');
    gps[2] = image.IfdValueRational.list([
      image.IfdValueRational(14, 1).value.single,
      image.IfdValueRational(57, 1).value.single,
      image.IfdValueRational(162, 10).value.single,
    ]);
    gps[3] = image.IfdValueAscii('E');
    gps[4] = image.IfdValueRational.list([
      image.IfdValueRational(120, 1).value.single,
      image.IfdValueRational(53, 1).value.single,
      image.IfdValueRational(582, 10).value.single,
    ]);
  }
  photo.exif.exifIfd[0x9003] = image.IfdValueAscii('2026:10:03 21:00:00');
  return image.encodeJpg(photo);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = PhotoMetadataService();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'reads original GPS/date and strips metadata from upload bytes',
    () async {
      final prepared = await service.prepare(photoFixture());
      expect(prepared.metadata.latitude, closeTo(14.9545, 0.00001));
      expect(prepared.metadata.longitude, closeTo(120.8995, 0.00001));
      expect(prepared.metadata.takenAt, DateTime(2026, 10, 3, 21));
      expect(prepared.metadataWarning, isNull);
      final uploadedTags = await readExifFromBytes(prepared.bytes);
      expect(uploadedTags, isEmpty);
      final resized = image.decodeJpg(prepared.bytes)!;
      expect(resized.width, 1280);
      expect(resized.height, 640);
    },
  );

  test(
    'a photo without GPS remains attachable without invented coordinates',
    () async {
      final prepared = await service.prepare(photoFixture(withGps: false));
      expect(prepared.metadata.hasLocation, isFalse);
      expect(image.decodeJpg(prepared.bytes), isNotNull);
    },
  );

  test('bakes orientation before stripping EXIF', () async {
    final prepared = await service.prepare(photoFixture(orientation: 6));
    final decoded = image.decodeJpg(prepared.bytes)!;
    expect(decoded.width, 640);
    expect(decoded.height, 1280);
  });

  test('rejects unsupported bytes with an explicit error', () async {
    await expectLater(
      service.prepare(Uint8List(16)),
      throwsA(isA<FormatException>()),
    );
  });

  test('native HEIC conversion sanitizes its JPEG result', () async {
    final heic = Uint8List(40)..setAll(4, 'ftypheic'.codeUnits);
    var converted = false;
    final nativeService = PhotoMetadataService(
      nativeConverter: (bytes) async {
        expect(bytes, heic);
        converted = true;
        return photoFixture();
      },
    );
    final result = await nativeService.prepare(heic);
    expect(converted, isTrue);
    expect(result.metadata.hasLocation, isFalse);
    expect(await readExifFromBytes(result.bytes), isEmpty);
    expect(image.decodeJpg(result.bytes)!.width, 1280);
  });

  test(
    'native conversion retains original metadata only in the draft',
    () async {
      final nativeService = PhotoMetadataService(
        nativeConverter: (_) async =>
            image.encodeJpg(image.Image(width: 32, height: 16)),
      );
      final result = await nativeService.prepare(photoFixture());
      expect(result.metadata.latitude, closeTo(14.9545, 0.00001));
      expect(result.metadata.takenAt, DateTime(2026, 10, 3, 21));
      expect(await readExifFromBytes(result.bytes), isEmpty);
    },
  );

  test(
    'HEIC without native codec support produces an explicit error',
    () async {
      final heic = Uint8List(40)..setAll(4, 'ftypheic'.codeUnits);
      await expectLater(service.prepare(heic), throwsA(isA<FormatException>()));
    },
  );

  Map<String, IfdTag> coordinateTags(
    String latRef,
    String lngRef, {
    int denominator = 1,
  }) => {
    'GPS GPSLatitudeRef': IfdTag(
      tag: 1,
      tagType: 'ASCII',
      printable: latRef,
      values: const IfdNone(),
    ),
    'GPS GPSLongitudeRef': IfdTag(
      tag: 3,
      tagType: 'ASCII',
      printable: lngRef,
      values: const IfdNone(),
    ),
    'GPS GPSLatitude': IfdTag(
      tag: 2,
      tagType: 'Ratio',
      printable: '',
      values: IfdRatios([Ratio(14, denominator), Ratio(30, 1), Ratio(0, 1)]),
    ),
    'GPS GPSLongitude': IfdTag(
      tag: 4,
      tagType: 'Ratio',
      printable: '',
      values: IfdRatios([Ratio(120, 1), Ratio(30, 1), Ratio(0, 1)]),
    ),
  };

  test('south and west references produce negative coordinates', () {
    final metadata = PhotoMetadata.fromTags(coordinateTags('S', 'W'));
    expect(metadata.latitude, -14.5);
    expect(metadata.longitude, -120.5);
  });

  test('incomplete, unknown-reference and non-finite GPS are rejected', () {
    expect(
      PhotoMetadata.fromTags(coordinateTags('?', 'E')).hasLocation,
      isFalse,
    );
    expect(
      PhotoMetadata.fromTags(
        coordinateTags('N', 'E', denominator: 0),
      ).hasLocation,
      isFalse,
    );
    final partial = coordinateTags('N', 'E')..remove('GPS GPSLongitude');
    expect(PhotoMetadata.fromTags(partial).hasLocation, isFalse);
  });

  test('invalid dates are not normalized into a different date', () {
    final metadata = PhotoMetadata.fromTags({
      'EXIF DateTimeOriginal': IfdTag(
        tag: 0x9003,
        tagType: 'ASCII',
        printable: '2026:02:31 12:00:00',
        values: const IfdNone(),
      ),
    });
    expect(metadata.takenAt, isNull);
  });
}
