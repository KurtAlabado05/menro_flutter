import 'dart:ui' show PointerDeviceKind;

import 'package:cenro_application/core/constants/app_tokens.dart';
import 'package:cenro_application/widgets/rounded_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final labels in [
    ['Active', 'Resolved'],
    ['Ongoing (2)', 'Not Started (2)', 'Done (0)'],
  ]) {
    testWidgets(
      '${labels.length} tabs have rounded hover and selection shapes',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DefaultTabController(
              length: labels.length,
              child: Scaffold(
                body: RoundedTabBar(
                  tabs: labels.map((label) => Tab(text: label)).toList(),
                ),
              ),
            ),
          ),
        );
        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar.splashBorderRadius, AppRadius.pillAll);
        expect(
          (tabBar.indicator! as BoxDecoration).borderRadius,
          AppRadius.pillAll,
        );
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(RoundedTabBar),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.clipBehavior, Clip.antiAlias);
        expect(material.borderRadius, AppRadius.pillAll);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.text(labels.last)));
        await tester.pumpAndSettle();
        await tester.tap(find.text(labels.last));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(TabBar));
        expect(DefaultTabController.of(context).index, labels.length - 1);
        await mouse.removePointer();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
