import 'package:cubeclash/core/theme/app_colors.dart';
import 'package:cubeclash/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

void main() {
  setUpAll(initTestFonts);

  group('AppButton', () {
    testWidgets('fires onPressed when enabled', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(AppButton(label: 'Start', onPressed: () => taps++)),
      );

      await tester.tap(find.text('Start'));
      expect(taps, 1);
    });

    testWidgets('a null onPressed is inert', (WidgetTester tester) async {
      await tester.pumpWidget(harness(const AppButton(label: 'Start')));
      await tester.tap(find.text('Start'));
      // Nothing to assert but the absence of a crash — the tap must be a no-op.
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading swaps the label for a spinner and blocks taps',
        (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(
          AppButton(label: 'Start', isLoading: true, onPressed: () => taps++),
        ),
      );

      expect(find.text('Start'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      expect(taps, 0, reason: 'a loading button must not re-submit');
    });
  });

  group('AppChip', () {
    testWidgets('penalty chips carry their status colors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[AppChip.plus2(), AppChip.dnf()],
          ),
        ),
      );

      expect(find.text('+2'), findsOneWidget);
      expect(find.text('DNF'), findsOneWidget);

      final Text plus2 = tester.widget<Text>(find.text('+2'));
      final Text dnf = tester.widget<Text>(find.text('DNF'));
      expect(plus2.style?.color, AppColors.light.statusWarning);
      expect(dnf.style?.color, AppColors.light.statusDanger);
    });

    testWidgets('a selected filter chip takes the brand color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(const AppChip(label: 'Global', selected: true)),
      );
      final Text label = tester.widget<Text>(find.text('Global'));
      expect(label.style?.color, AppColors.light.brandPrimary);
    });
  });

  group('AppSegmentedControl', () {
    testWidgets('reports the tapped index', (WidgetTester tester) async {
      int? changed;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 320,
            child: AppSegmentedControl(
              segments: const <String>['Quick', 'Private', 'Tournaments'],
              selectedIndex: 0,
              onChanged: (int i) => changed = i,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Private'));
      expect(changed, 1);
    });
  });

  group('AppTextField', () {
    testWidgets('shows the error message when errorText is set',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          const SizedBox(
            width: 320,
            child: AppTextField(
              label: 'Email',
              errorText: 'That email is already taken',
            ),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('That email is already taken'), findsOneWidget);
    });
  });

  group('StatCard', () {
    testWidgets('renders an em-dash when there is no value yet',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(const SizedBox(
            width: 160,
            child: StatCard(
              label: 'Ao12',
              value: null,
            ))),
      );

      expect(find.text('AO12'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('LeaderboardRow', () {
    testWidgets('renders rank, name, flag and time',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          const SizedBox(
            width: 360,
            child: LeaderboardRow(
              rank: 1,
              displayName: 'Ada Speedcube',
              time: '6.12',
              countryCode: 'GB',
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Ada Speedcube'), findsOneWidget);
      expect(find.text('6.12'), findsOneWidget);
      expect(find.text('🇬🇧'), findsOneWidget);
    });
  });

  group('countryCodeToFlag', () {
    test('maps alpha-2 codes to regional-indicator pairs', () {
      expect(countryCodeToFlag('GB'), '🇬🇧');
      expect(countryCodeToFlag('us'), '🇺🇸');
      expect(countryCodeToFlag(' jp '), '🇯🇵');
    });

    test('rejects anything that is not two ASCII letters', () {
      expect(countryCodeToFlag(null), isNull);
      expect(countryCodeToFlag(''), isNull);
      expect(countryCodeToFlag('GBR'), isNull);
      expect(countryCodeToFlag('G1'), isNull);
    });
  });

  group('state views', () {
    testWidgets('EmptyState renders its action', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        harness(
          EmptyState(
            title: 'No solves yet',
            message: 'Your first solve will show up here.',
            actionLabel: 'Start solving',
            onAction: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('Start solving'));
      expect(taps, 1);
    });

    testWidgets('ErrorState retries', (WidgetTester tester) async {
      int retries = 0;
      await tester.pumpWidget(
        harness(ErrorState(onRetry: () => retries++)),
      );

      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('ErrorState without onRetry shows no button',
        (WidgetTester tester) async {
      await tester.pumpWidget(harness(const ErrorState()));
      expect(find.byType(AppButton), findsNothing);
    });
  });

  group('CubeFaceIcon', () {
    testWidgets('picks a shape from the event string',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CubeFaceIcon.forEvent('3x3'),
              CubeFaceIcon.forEvent('megaminx'),
              CubeFaceIcon.forEvent('pyraminx'),
            ],
          ),
        ),
      );

      final List<CubeFaceIcon> icons =
          tester.widgetList<CubeFaceIcon>(find.byType(CubeFaceIcon)).toList();
      expect(icons[0].shape, PuzzleShape.nxn);
      expect(icons[0].n, 3);
      expect(icons[1].shape, PuzzleShape.pentagon);
      expect(icons[2].shape, PuzzleShape.triangle);
    });

    testWidgets('unknown events fall back to a 3x3 face',
        (WidgetTester tester) async {
      await tester.pumpWidget(harness(CubeFaceIcon.forEvent('squan')));
      final CubeFaceIcon icon =
          tester.widget<CubeFaceIcon>(find.byType(CubeFaceIcon));
      expect(icon.shape, PuzzleShape.nxn);
      expect(icon.n, 3);
    });
  });
}
