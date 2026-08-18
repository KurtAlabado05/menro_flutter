import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cenro_application/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CenroApp());
    expect(find.text('CENRO Connect'), findsOneWidget);
  });
}

