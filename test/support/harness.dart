import 'dart:io';

import 'package:cubeclash/core/theme/app_theme.dart';
import 'package:cubeclash/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared test scaffolding.

/// Registers the bundled Noto Serif variable font with the test binding.
///
/// `flutter test` does not load the asset bundle, so without this every widget
/// renders in the fallback test font — which makes goldens meaningless as a
/// check on typography. Call from `setUpAll` in any test that pumps a widget.
Future<void> initTestFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final FontLoader loader = FontLoader(AppTypography.fontFamily)
    ..addFont(
      File('assets/fonts/NotoSerif-Variable.ttf')
          .readAsBytes()
          .then((Uint8List bytes) => bytes.buffer.asByteData()),
    );
  await loader.load();
}

/// Wraps [child] in a themed [MaterialApp] so `context.colors` and the text
/// theme resolve exactly as they do in the app.
///
/// Note for golden readers: emoji (country flags) render as tofu here. Noto
/// Serif carries no emoji glyphs and the test environment has no emoji
/// fallback font — on a real device the platform supplies one. The boxes in
/// the leaderboard goldens are an artefact of the harness, not a defect.
Widget harness(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  Size? size,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(
        size: size ?? const Size(400, 800),
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// Pumps [child] in both light and dark and asserts each against a golden.
///
/// Files land in `test/goldens/<name>_light.png` / `<name>_dark.png`.
/// Regenerate with `flutter test --update-goldens`.
/// Set [settle] to false for specimens containing a perpetual animation (a
/// [CircularProgressIndicator], say) — `pumpAndSettle` never returns on those,
/// so we pump a fixed, deterministic number of frames instead.
Future<void> expectGoldenBothThemes(
  WidgetTester tester,
  Widget child, {
  required String name,
  Size surfaceSize = const Size(360, 240),
  bool settle = true,
}) async {
  for (final (String suffix, Brightness brightness) in <(String, Brightness)>[
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    await tester.binding.setSurfaceSize(surfaceSize);
    await tester.pumpWidget(
      harness(child, brightness: brightness, size: surfaceSize),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/${name}_$suffix.png'),
    );
  }
  await tester.binding.setSurfaceSize(null);
}
