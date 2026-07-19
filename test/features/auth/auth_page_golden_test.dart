import 'package:cubeclash/core/di/injection.dart';
import 'package:cubeclash/core/widgets/widgets.dart';
import 'package:cubeclash/features/auth/presentation/pages/profile_setup_page.dart';
import 'package:cubeclash/features/auth/presentation/pages/sign_in_page.dart';
import 'package:cubeclash/features/auth/presentation/pages/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

void main() {
  setUpAll(initTestFonts);

  setUp(configureDependencies);
  tearDown(resetDependencies);

  const Size phone = Size(390, 780);

  Future<void> goldenFor(
    WidgetTester tester,
    Widget page, {
    required String name,
  }) async {
    for (final (String suffix, Brightness brightness) in <(String, Brightness)>[
      ('light', Brightness.light),
      ('dark', Brightness.dark),
    ]) {
      await tester.binding.setSurfaceSize(phone);
      await tester.pumpWidget(
        harnessPage(page, brightness: brightness, size: phone),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/auth_${name}_$suffix.png'),
      );
    }
    await tester.binding.setSurfaceSize(null);
  }

  testWidgets('welcome', (WidgetTester tester) async {
    await goldenFor(tester, const WelcomePage(), name: 'welcome');
  });

  testWidgets('log in', (WidgetTester tester) async {
    await goldenFor(
      tester,
      const SignInPage(isRegister: false),
      name: 'login',
    );
  });

  testWidgets('sign up', (WidgetTester tester) async {
    await goldenFor(
      tester,
      const SignInPage(isRegister: true),
      name: 'register',
    );
  });

  testWidgets('profile setup', (WidgetTester tester) async {
    await goldenFor(tester, const ProfileSetupPage(), name: 'setup');
  });

  group('validation', () {
    testWidgets('submitting an empty sign-up shows every error at once',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harnessPage(const SignInPage(isRegister: true), size: phone),
      );
      await tester.pumpAndSettle();

      // The submit button sits below the fold on a phone-sized viewport.
      final Finder submit = find.widgetWithText(AppButton, 'Create account');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      // All three, not just the first — the user shouldn't discover them one
      // submit at a time.
      expect(find.text('Pick a display name.'), findsOneWidget);
      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Enter a password.'), findsOneWidget);
    });

    testWidgets('a short password is rejected before hitting the network',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harnessPage(const SignInPage(isRegister: false), size: phone),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'you@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'short');

      final Finder submit = find.widgetWithText(AppButton, 'Log in');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('Use at least 8 characters.'), findsOneWidget);
    });
  });
}
