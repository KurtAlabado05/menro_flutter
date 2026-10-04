import 'dart:convert';
import 'dart:async';

import 'package:cenro_application/screens/map/map_screen.dart';
import 'package:cenro_application/services/map_records_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

class _Tiles extends TileProvider {
  final _image = MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
    ),
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _image;
}

const _report = MapDocument('report', {
  'title': 'Test report',
  'latitude': 14.9545,
  'longitude': 120.8995,
});
const _project = MapDocument('project', {
  'title': 'Test project',
  'latitude': 14.96,
  'longitude': 120.90,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const locationChannel = MethodChannel('flutter.baseflow.com/geolocator');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(locationChannel, (_) async => false);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(locationChannel, null);
  });

  Future<void> showMap(
    WidgetTester tester,
    MapRecordsService service, {
    Size size = const Size(620, 1040),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(recordsService: service, tileProvider: _Tiles()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('zoom buttons change the actual camera and stop at limits', (
    tester,
  ) async {
    await showMap(
      tester,
      MapRecordsService(
        reportsLoader: () async => [_report],
        projectsLoader: () async => [_project],
      ),
    );
    final controller = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!;
    expect(controller.zoom, 12);
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    expect(controller.zoom, 13);
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pumpAndSettle();
    expect(controller.zoom, 12);
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pumpAndSettle();
    expect(controller.zoom, 11);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
          .onPressed,
      isNull,
    );
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
    }
    expect(controller.zoom, 17);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads both marker layers and switches filters', (tester) async {
    await showMap(
      tester,
      MapRecordsService(
        reportsLoader: () async => [_report],
        projectsLoader: () async => [_project],
      ),
    );
    expect(find.text('Reports (1)'), findsOneWidget);
    expect(find.text('Projects (1)'), findsOneWidget);
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(2),
    );
    await tester.tap(find.text('Projects (1)'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(1),
    );
    await tester.tap(find.text('Reports (1)'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'partial failure keeps projects visible and Retry restores reports',
    (tester) async {
      var fail = true;
      await showMap(
        tester,
        MapRecordsService(
          reportsLoader: () async {
            if (fail) {
              throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'permission-denied',
              );
            }
            return [_report];
          },
          projectsLoader: () async => [_project],
        ),
      );
      expect(find.text('Projects (1)'), findsOneWidget);
      expect(find.textContaining('access to these reports'), findsOneWidget);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        hasLength(1),
      );
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Reports (1)'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        hasLength(2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'error and coordinate notices do not cover zoom controls on a narrow screen',
    (tester) async {
      await showMap(
        tester,
        MapRecordsService(
          reportsLoader: () async => throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          ),
          projectsLoader: () async => [
            _project,
            const MapDocument('unmapped', {'title': 'No location yet'}),
          ],
        ),
        size: const Size(380, 800),
      );
      expect(find.textContaining('missing or invalid'), findsOneWidget);
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      expect(controller.zoom, 13);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'leaving during a pending record load does not update disposed state',
    (tester) async {
      final pending = Completer<List<MapDocument>>();
      await showMap(
        tester,
        MapRecordsService(
          reportsLoader: () => pending.future,
          projectsLoader: () async => [_project],
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      pending.complete([_report]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
