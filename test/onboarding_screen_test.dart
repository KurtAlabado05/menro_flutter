import 'package:cenro_application/screens/auth/login_screen.dart';
import 'package:cenro_application/screens/onboarding/onboarding_screen.dart';
import 'package:cenro_application/screens/onboarding/onboarding_slide_data.dart';
import 'package:cenro_application/widgets/app_brand_logos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('all onboarding pages fit a short screen and finish at login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(AppBrandLogos), findsOneWidget);
    for (var index = 0; index < onboardingSlides.length; index++) {
      expect(find.text(onboardingSlides[index].title), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.text(
          index == onboardingSlides.length - 1 ? 'Get Started' : 'Next',
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'login replay closes without changing returning-device preference',
    (tester) async {
      SharedPreferences.setMockInitialValues({'has_logged_in_before': true});
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View app introduction'));
      await tester.tap(find.text('View app introduction'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getBool('has_logged_in_before'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
