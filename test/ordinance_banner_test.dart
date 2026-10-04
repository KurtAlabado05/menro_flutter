import 'dart:ui' show PointerDeviceKind;

import 'package:cenro_application/core/constants/app_tokens.dart';
import 'package:cenro_application/screens/dashboard/ordinances_screen.dart';
import 'package:cenro_application/screens/dashboard/widgets/ordinance_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rounded hover overlay covers the image and the footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 300, child: OrdinanceBanner())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final banner = find.byType(OrdinanceBanner);
    final ink = find.descendant(of: banner, matching: find.byType(InkWell));
    expect(tester.widget<InkWell>(ink).borderRadius, AppRadius.lgAll);
    expect(tester.getRect(ink), tester.getRect(banner));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getRect(ink).topCenter + const Offset(0, 20));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getRect(ink).topCenter + const Offset(0, 20));
    await tester.pumpAndSettle();
    expect(find.byType(OrdinancesScreen), findsOneWidget);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
}
