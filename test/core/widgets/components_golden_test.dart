import 'package:cubeclash/core/theme/app_spacing.dart';
import 'package:cubeclash/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/harness.dart';

/// Golden coverage for the shared component library, light + dark.
///
/// These lock the design-token wiring in place — a component that starts
/// hardcoding a color or drifting off the spacing scale changes pixels here.
/// Regenerate deliberately: `flutter test --update-goldens`.
void main() {
  setUpAll(initTestFonts);

  testWidgets('AppButton — every variant and state',
      (WidgetTester tester) async {
    await expectGoldenBothThemes(
      tester,
      const _Specimen(
        children: <Widget>[
          AppButton(label: 'Start solve', onPressed: _noop),
          AppButton(label: 'Disabled'),
          AppButton(label: 'Submitting', isLoading: true, onPressed: _noop),
          AppButton.secondary(label: 'New scramble', onPressed: _noop),
          AppButton.ghost(label: 'Skip', onPressed: _noop),
        ],
      ),
      name: 'app_button',
      surfaceSize: const Size(360, 420),
      // The loading variant spins forever — pump fixed frames, don't settle.
      settle: false,
    );
  });

  testWidgets('AppChip — event, penalties, filters',
      (WidgetTester tester) async {
    await expectGoldenBothThemes(
      tester,
      const _Specimen(
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              AppChip(label: '3×3', variant: AppChipVariant.event),
              AppChip.plus2(),
              AppChip.dnf(),
              AppChip(label: 'Global', selected: true),
              AppChip(label: 'Friends'),
            ],
          ),
        ],
      ),
      name: 'app_chip',
      surfaceSize: const Size(360, 180),
    );
  });

  testWidgets('AppSegmentedControl', (WidgetTester tester) async {
    await expectGoldenBothThemes(
      tester,
      const _Specimen(
        children: <Widget>[
          AppSegmentedControl(
            segments: <String>['Quick Match', 'Private', 'Tournaments'],
            selectedIndex: 0,
            onChanged: _noopInt,
          ),
          AppSegmentedControl(
            segments: <String>['My Stats', 'Leaderboards'],
            selectedIndex: 1,
            onChanged: _noopInt,
          ),
        ],
      ),
      name: 'app_segmented_control',
      surfaceSize: const Size(360, 200),
    );
  });

  testWidgets('AppTextField — default and error', (WidgetTester tester) async {
    await expectGoldenBothThemes(
      tester,
      const _Specimen(
        children: <Widget>[
          AppTextField(label: 'Display name', hintText: 'cuber99'),
          AppTextField(
            label: 'Email',
            hintText: 'you@example.com',
            errorText: 'That email is already taken',
          ),
        ],
      ),
      name: 'app_text_field',
      surfaceSize: const Size(360, 280),
    );
  });

  testWidgets('StatCard row', (WidgetTester tester) async {
    await expectGoldenBothThemes(
      tester,
      const _Specimen(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: StatCard(
                  label: 'Best',
                  value: '8.42',
                  caption: '2 days ago',
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(child: StatCard(label: 'Ao5', value: '11.07')),
              SizedBox(width: AppSpacing.md),
              Expanded(child: StatCard(label: 'Ao100', value: null)),
            ],
          ),
        ],
      ),
      name: 'stat_card',
      surfaceSize: const Size(400, 200),
    );
  });

  testWidgets('LeaderboardRow — podium and current user',
      (WidgetTester tester) async {
    await expectGoldenBothThemes(
      tester,
      const _Specimen(
        children: <Widget>[
          LeaderboardRow(
            rank: 1,
            displayName: 'Yuki Tanaka',
            time: '5.98',
            countryCode: 'JP',
          ),
          LeaderboardRow(
            rank: 2,
            displayName: 'Ana Silva',
            time: '6.31',
            countryCode: 'BR',
          ),
          LeaderboardRow(
            rank: 3,
            displayName: 'Tomas Novak',
            time: '6.44',
            countryCode: 'CZ',
          ),
          LeaderboardRow(
            rank: 42,
            displayName: 'You',
            time: '11.20',
            countryCode: 'GB',
            isCurrentUser: true,
          ),
        ],
      ),
      name: 'leaderboard_row',
      surfaceSize: const Size(380, 380),
    );
  });

  testWidgets('CubeFaceIcon — shapes and densities',
      (WidgetTester tester) async {
    await expectGoldenBothThemes(
      tester,
      const _Specimen(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              CubeFaceIcon(n: 2, size: 40),
              CubeFaceIcon(n: 3, size: 40, active: true),
              CubeFaceIcon(n: 7, size: 40),
              CubeFaceIcon(shape: PuzzleShape.pentagon, size: 40),
              CubeFaceIcon(shape: PuzzleShape.triangle, size: 40),
            ],
          ),
        ],
      ),
      name: 'cube_face_icon',
      surfaceSize: const Size(360, 120),
    );
  });

  testWidgets('state views', (WidgetTester tester) async {
    await expectGoldenBothThemes(
      tester,
      const EmptyState(
        title: 'No solves yet',
        message: 'Hit the timer to record your first solve.',
        icon: Icons.timer_outlined,
        actionLabel: 'Start solving',
        onAction: _noop,
      ),
      name: 'empty_state',
      surfaceSize: const Size(360, 320),
    );

    await expectGoldenBothThemes(
      tester,
      const ErrorState(
        message: "We couldn't load the leaderboard.",
        onRetry: _noop,
      ),
      name: 'error_state',
      surfaceSize: const Size(360, 320),
    );
  });
}

void _noop() {}
void _noopInt(int _) {}

/// Vertical stack with consistent padding so specimens compose the same way.
class _Specimen extends StatelessWidget {
  const _Specimen({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            children[i],
          ],
        ],
      ),
    );
  }
}
