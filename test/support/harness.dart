import 'dart:convert';

import 'package:cubeclash/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared test scaffolding.

/// Registers every font in the app's asset bundle with the test binding.
///
/// `flutter test` ships no fonts by default: text renders in a fallback face
/// and — less obviously — **every `Icon` renders as an empty box**, because
/// MaterialIcons is a font too. Goldens taken without this are checking a
/// layout that no user will ever see.
///
/// Reading `FontManifest.json` rather than hard-coding paths means this picks
/// up MaterialIcons, our bundled Noto Serif, and anything added later, with no
/// extra dependency and nothing machine-specific to break in CI.
///
/// Call from `setUpAll` in any test that pumps a widget.
Future<void> initTestFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final String manifestJson = await rootBundle.loadString('FontManifest.json');
  final List<dynamic> manifest = json.decode(manifestJson) as List<dynamic>;

  for (final dynamic entry in manifest) {
    final Map<String, dynamic> family = Map<String, dynamic>.from(entry as Map);
    final FontLoader loader = FontLoader(family['family'] as String);

    for (final dynamic asset in family['fonts'] as List<dynamic>) {
      final String path =
          Map<String, dynamic>.from(asset as Map)['asset'] as String;
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
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

/// Like [harness], but hands [page] the whole viewport instead of centring it.
///
/// Full screens supply their own [Scaffold] and use [Expanded]/[Spacer], which
/// need a bounded height — the `Center` in [harness] gives them an unbounded
/// one, and the layout silently collapses. Use this for anything that is a
/// route; use [harness] for individual components.
Widget harnessPage(
  Widget page, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  Size size = const Size(400, 800),
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        disableAnimations: disableAnimations,
      ),
      child: page,
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
