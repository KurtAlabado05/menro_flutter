import 'package:cenro_application/screens/auth/login_screen.dart';
import 'package:cenro_application/screens/auth/register_screen.dart';
import 'package:cenro_application/widgets/app_brand_logos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled display logos decode and occupy their square canvases', () async {
    for (final asset in [
      AppBrandLogos.ecoMapAsset,
      AppBrandLogos.partnerAsset,
    ]) {
      final bytes = await rootBundle.load(asset);
      final decoded = image.decodePng(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      expect(decoded, isNotNull, reason: asset);
      expect(decoded!.width, 512);
      expect(decoded.height, 512);
      var left = 512;
      var right = -1;
      var top = 512;
      var bottom = -1;
      for (final pixel in decoded) {
        if (pixel.a <= 16) continue;
        if (pixel.x < left) left = pixel.x;
        if (pixel.x > right) right = pixel.x;
        if (pixel.y < top) top = pixel.y;
        if (pixel.y > bottom) bottom = pixel.y;
      }
      expect(right - left + 1, greaterThanOrEqualTo(300), reason: asset);
      expect(bottom - top + 1, greaterThanOrEqualTo(430), reason: asset);
    }
  });

  Future<void> setScreen(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  void expectBothLogos(WidgetTester tester) {
    final images = tester.widgetList<Image>(
      find.descendant(
        of: find.byType(AppBrandLogos),
        matching: find.byType(Image),
      ),
    );
    expect(images.map((image) => (image.image as AssetImage).assetName), [
      AppBrandLogos.ecoMapAsset,
      AppBrandLogos.partnerAsset,
    ]);
    expect(images.map((image) => image.semanticLabel), [
      'EcoMap logo',
      'MENRO partner, Baliwag city seal',
    ]);
  }

  for (final screen in <String, Widget>{
    'login': const LoginScreen(),
    'registration': const RegisterScreen(),
  }.entries) {
    testWidgets('${screen.key} shows both logos on a small screen', (
      tester,
    ) async {
      await setScreen(tester, const Size(320, 640));
      await tester.pumpWidget(MaterialApp(home: screen.value));
      await tester.pumpAndSettle();
      expect(find.byType(AppBrandLogos), findsOneWidget);
      expectBothLogos(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact branding fits a narrow header with three actions', (
    tester,
  ) async {
    await setScreen(tester, const Size(320, 640));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            toolbarHeight: 120,
            title: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBrandLogos(size: 44, gap: 8),
                SizedBox(height: 4),
                Text(
                  'Good afternoon, Community Organization',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 19),
                ),
                Text(
                  'Baliwag City, Bulacan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              for (final icon in [
                Icons.notifications,
                Icons.support_agent,
                Icons.map,
              ])
                IconButton(onPressed: () {}, icon: Icon(icon)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expectBothLogos(tester);
    final logos = find.descendant(
      of: find.byType(AppBrandLogos),
      matching: find.byType(Image),
    );
    for (final logo in logos.evaluate()) {
      expect(tester.getSize(find.byWidget(logo.widget)), const Size(44, 44));
    }
    expect(
      find.descendant(
        of: find.byType(AppBrandLogos),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
