import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cenro_application/main.dart';
import 'package:cenro_application/screens/virtual_assistant_screen.dart';
import 'package:cenro_application/core/constants/app_colors.dart';
import 'package:cenro_application/services/citizen_charter_knowledge_base.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CenroApp());
    expect(find.text('CENRO Connect'), findsOneWidget);
  });

  testWidgets('guided assistant answers across service modules', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: VirtualAssistantScreen()));

    expect(find.text('CENRO Virtual Assistant'), findsOneWidget);
    expect(
      find.text(
        'General guidance only. Case details and official decisions stay with MENRO staff.',
      ),
      findsOneWidget,
    );
    final suggestionChip = tester.widget<ActionChip>(
      find.ancestor(
        of: find.text('How do I file a report?'),
        matching: find.byType(ActionChip),
      ),
    );
    expect(suggestionChip.labelStyle?.color, AppColors.textDark);

    await tester.enterText(find.byType(TextField), 'How do I file a report?');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(find.text('Start an environmental report'), findsOneWidget);

    await tester.tap(find.text('Permits'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Do hospitals need a no objection clearance and what paperwork should I prepare?',
    );
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Business Permit'), findsOneWidget);
    expect(find.textContaining('Citizen Charter'), findsOneWidget);
    expect(find.text('Start a permit application'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'How much do I pay?');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(find.textContaining('list NONE for fees'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Can I appeal an inspection decision?',
    );
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(find.textContaining('do not want to guess'), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'How do I find a project?');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(find.textContaining('browse community projects'), findsOneWidget);
    expect(find.text('Browse community projects'), findsOneWidget);

    await tester.tap(find.text('EcoMap'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Where is the MENRO Baliwag office?',
    );
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Baliwag Climate Change Center'), findsOneWidget);
    expect(find.textContaining('798-0391 local 3676'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'What does the environmental map show?',
    );
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(find.textContaining('location coordinates'), findsOneWidget);
    expect(find.text('Open environmental map'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'How much are MENRO fees?');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(find.textContaining('list NONE for fees'), findsOneWidget);
    expect(find.text('Start a permit application'), findsOneWidget);
  });

  test('charter retrieval handles paraphrased checklist questions', () {
    final answer = CitizenCharterKnowledgeBase.answerPermitQuestion(
      'Could you list the papers for trimming a tree?',
    );

    expect(answer, contains('Sketch Plan'));
    expect(answer, contains('referendum for HOA cases'));
    expect(answer, contains('Citizen Charter'));
    expect(
      CitizenCharterKnowledgeBase.answerPermitQuestion(
        'Can I appeal an inspection decision?',
      ),
      isNull,
    );
  });

  test('EcoMap knowledge answers map and MENRO contact questions', () {
    expect(
      CitizenCharterKnowledgeBase.answerEcoMapQuestion(
        'Where is the MENRO Baliwag office?',
      ),
      contains('Baliwag Climate Change Center'),
    );
    expect(
      CitizenCharterKnowledgeBase.answerEcoMapQuestion(
        'What does the environmental map show?',
      ),
      contains('location coordinates'),
    );
    expect(
      CitizenCharterKnowledgeBase.answerEcoMapQuestion(
        'Can I appeal an inspection decision?',
      ),
      isNull,
    );
  });
}
