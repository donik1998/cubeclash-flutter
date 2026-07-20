import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Puzzle families the icon can draw.
enum PuzzleShape {
  /// NxN cubes (2×2 … 9×9) — an n×n grid inside a rounded square.
  nxn,

  /// Megaminx / teraminx — a pentagon.
  pentagon,

  /// Pyraminx — a triangle.
  triangle,

  /// Skewb — a square cut corner-to-corner, which is exactly how a skewb
  /// turns and the only thing that distinguishes it from a 2×2 at 24px.
  skewb,

  /// Square-1 — a square bisected off-centre, showing the shape-shift.
  square1,

  /// Clock — a circle with hands. Not a twisty puzzle at all, and the icon
  /// says so rather than pretending.
  clock,
}

/// A discipline drawn as a badge on top of a base shape.
///
/// See `PuzzleModifier` in the timer domain for why the icon set composes
/// rather than enumerating: seventeen events are eleven puzzles and five
/// disciplines, and `3BLD` should read as a 3×3 at a glance because it *is*
/// one.
enum PuzzleBadge {
  none,

  /// Blindfolded — a bar across the upper third of the face, like a blindfold.
  blindfolded,

  /// One-Handed — a single dot, one where the base would have two.
  oneHanded,

  /// Fewest Moves — a hash, for a written solution rather than a timed one.
  fewestMoves,

  /// Multi-Blind — a blindfold bar over stacked faces.
  multiBlind,
}

/// Event icon, per the design system's iconography rules: line art, stroke 2,
/// round caps and joins, tinted `brand/primary` when active and `text/muted`
/// when not.
///
/// For [PuzzleShape.nxn] the grid density encodes the puzzle: [n] of 3 draws a
/// 3×3 face, [n] of 4 a 4×4, and so on. [badge] composes a discipline on top —
/// the same 3×3 face reads as 3×3, 3BLD, OH, FMC or MBLD depending on it.
///
/// Hand-painted rather than an SVG export because it is *parametric*: one
/// painter covers every N and every badge, where `tool/figma_icons.md`'s
/// export flow would need a file per combination. The same reasoning as the
/// stats charts.
class CubeFaceIcon extends StatelessWidget {
  const CubeFaceIcon({
    super.key,
    this.shape = PuzzleShape.nxn,
    this.n = 3,
    this.size = 24,
    this.active = false,
    this.color,
    this.badge = PuzzleBadge.none,
  }) : assert(n >= 2 && n <= 9, 'NxN icons are defined for 2×2 … 9×9');

  /// Convenience: the icon for an event id (`3x3`, `4x4-bld`, `megaminx`, …).
  ///
  /// Keeps its own event table rather than reading `WcaEvent`, because
  /// `core/` must not depend on `features/`. Callers inside the timer feature
  /// pass [shape]/[n]/[badge] explicitly from the domain instead; this factory
  /// is for the places (chips, leaderboard rows) that only have a string.
  factory CubeFaceIcon.forEvent(
    String event, {
    Key? key,
    double size = 24,
    bool active = false,
    Color? color,
  }) {
    final String e = event.toLowerCase().trim();

    final PuzzleBadge badge = switch (true) {
      _ when e.endsWith('-mbld') => PuzzleBadge.multiBlind,
      _ when e.endsWith('-bld') => PuzzleBadge.blindfolded,
      _ when e.endsWith('-oh') => PuzzleBadge.oneHanded,
      _ when e.endsWith('-fmc') => PuzzleBadge.fewestMoves,
      _ => PuzzleBadge.none,
    };

    // Strip the discipline suffix — what remains names the puzzle.
    final String puzzle = e.split('-').first;

    final PuzzleShape? shape = switch (puzzle) {
      'megaminx' || 'teraminx' => PuzzleShape.pentagon,
      'pyraminx' => PuzzleShape.triangle,
      'skewb' => PuzzleShape.skewb,
      'square' || 'sq1' => PuzzleShape.square1,
      'clock' => PuzzleShape.clock,
      _ => null,
    };

    if (shape != null) {
      return CubeFaceIcon(
        key: key,
        shape: shape,
        size: size,
        active: active,
        color: color,
        badge: badge,
      );
    }

    // `3x3` / `4x4` / … — fall back to 3 for anything unrecognised.
    final int parsed = int.tryParse(puzzle.split('x').first) ?? 3;
    return CubeFaceIcon(
      key: key,
      n: parsed.clamp(2, 9),
      size: size,
      active: active,
      color: color,
      badge: badge,
    );
  }

  final PuzzleShape shape;
  final int n;
  final double size;
  final bool active;
  final Color? color;
  final PuzzleBadge badge;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Color tint =
        color ?? (active ? colors.brandPrimary : colors.textMuted);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter:
            _CubeFacePainter(shape: shape, n: n, color: tint, badge: badge),
      ),
    );
  }
}

class _CubeFacePainter extends CustomPainter {
  const _CubeFacePainter({
    required this.shape,
    required this.n,
    required this.color,
    required this.badge,
  });

  final PuzzleShape shape;
  final int n;
  final Color color;
  final PuzzleBadge badge;

  @override
  void paint(Canvas canvas, Size size) {
    // Stroke 2 at the design system's nominal 24px, scaled proportionally so
    // the icon reads the same at any size.
    final double stroke = 2 * (size.width / 24);
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Rect bounds = Offset.zero & size;
    Rect inset = bounds.deflate(stroke / 2);

    // A badge needs a corner. Shrinking the base rather than overlapping it
    // keeps both legible — an overlaid badge on a 9×9 grid is mud.
    if (badge != PuzzleBadge.none) {
      inset = Rect.fromLTWH(
        inset.left,
        inset.top,
        inset.width * 0.78,
        inset.height * 0.78,
      );
    }

    switch (shape) {
      case PuzzleShape.nxn:
        _paintGrid(canvas, inset, paint, stroke);
      case PuzzleShape.pentagon:
        canvas.drawPath(_regularPolygon(inset, 5, -90), paint);
      case PuzzleShape.triangle:
        canvas.drawPath(_regularPolygon(inset, 3, -90), paint);
      case PuzzleShape.skewb:
        _paintSkewb(canvas, inset, paint);
      case PuzzleShape.square1:
        _paintSquare1(canvas, inset, paint);
      case PuzzleShape.clock:
        _paintClock(canvas, inset, paint, stroke);
    }

    if (badge != PuzzleBadge.none) {
      _paintBadge(canvas, bounds, paint, stroke);
    }
  }

  void _paintGrid(Canvas canvas, Rect inset, Paint paint, double stroke) {
    final RRect outer = RRect.fromRectAndRadius(
      inset,
      Radius.circular(inset.width * 0.18),
    );
    canvas.drawRRect(outer, paint);

    // Interior lines only — the outer rounded square already bounds the face.
    final double cellW = inset.width / n;
    final double cellH = inset.height / n;
    // Inner strokes are lighter so a 9×9 does not read as a solid block.
    final Paint inner = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.7
      ..strokeCap = StrokeCap.round;

    for (int i = 1; i < n; i++) {
      final double x = inset.left + cellW * i;
      final double y = inset.top + cellH * i;
      canvas.drawLine(Offset(x, inset.top), Offset(x, inset.bottom), inner);
      canvas.drawLine(Offset(inset.left, y), Offset(inset.right, y), inner);
    }
  }

  /// A rounded square with both diagonals — the corner-turning cut that is the
  /// whole point of a skewb.
  void _paintSkewb(Canvas canvas, Rect inset, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset, Radius.circular(inset.width * 0.18)),
      paint,
    );
    canvas.drawLine(inset.topLeft, inset.bottomRight, paint);
    canvas.drawLine(inset.topRight, inset.bottomLeft, paint);
  }

  /// A square with one off-centre horizontal cut and one off-centre vertical —
  /// the asymmetry *is* the identity of Square-1.
  void _paintSquare1(Canvas canvas, Rect inset, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset, Radius.circular(inset.width * 0.18)),
      paint,
    );
    final double cut = inset.top + inset.height * 0.5;
    canvas.drawLine(Offset(inset.left, cut), Offset(inset.right, cut), paint);
    final double vertical = inset.left + inset.width * 0.62;
    canvas.drawLine(
      Offset(vertical, inset.top),
      Offset(vertical, cut),
      paint,
    );
  }

  /// A dial with two hands — the one event in the set that is not a twisty
  /// puzzle, drawn as what it actually is.
  void _paintClock(Canvas canvas, Rect inset, Paint paint, double stroke) {
    final Offset centre = inset.center;
    final double radius = inset.shortestSide / 2;
    canvas.drawCircle(centre, radius, paint);
    canvas.drawLine(centre, centre.translate(0, -radius * 0.55), paint);
    canvas.drawLine(centre, centre.translate(radius * 0.42, 0), paint);
  }

  /// The discipline badge, bottom-right, in the corner the base shape vacated.
  void _paintBadge(Canvas canvas, Rect bounds, Paint paint, double stroke) {
    final double side = bounds.width * 0.42;
    final Rect box = Rect.fromLTWH(
      bounds.right - side,
      bounds.bottom - side,
      side,
      side,
    );
    final Paint thin = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.85
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (badge) {
      case PuzzleBadge.none:
        return;

      case PuzzleBadge.blindfolded:
        // A blindfold: one horizontal bar across a small face.
        canvas.drawLine(
          Offset(box.left, box.center.dy),
          Offset(box.right, box.center.dy),
          thin,
        );

      case PuzzleBadge.multiBlind:
        // A blindfold over *stacked* faces — several cubes, one blindfold.
        canvas.drawLine(
          Offset(box.left, box.center.dy - side * 0.22),
          Offset(box.right, box.center.dy - side * 0.22),
          thin,
        );
        canvas.drawLine(
          Offset(box.left, box.center.dy + side * 0.22),
          Offset(box.right, box.center.dy + side * 0.22),
          thin,
        );

      case PuzzleBadge.oneHanded:
        // A single filled dot: one, where two hands would be two.
        canvas.drawCircle(
          box.center,
          side * 0.2,
          Paint()
            ..color = paint.color
            ..style = PaintingStyle.fill,
        );

      case PuzzleBadge.fewestMoves:
        // A hash — a written solution rather than a measured one.
        final double q = side * 0.28;
        canvas.drawLine(
          Offset(box.center.dx - q, box.top + q * 0.6),
          Offset(box.center.dx - q, box.bottom - q * 0.6),
          thin,
        );
        canvas.drawLine(
          Offset(box.center.dx + q, box.top + q * 0.6),
          Offset(box.center.dx + q, box.bottom - q * 0.6),
          thin,
        );
        canvas.drawLine(
          Offset(box.left + q * 0.6, box.center.dy - q),
          Offset(box.right - q * 0.6, box.center.dy - q),
          thin,
        );
        canvas.drawLine(
          Offset(box.left + q * 0.6, box.center.dy + q),
          Offset(box.right - q * 0.6, box.center.dy + q),
          thin,
        );
    }
  }

  /// A regular [sides]-gon inscribed in [rect], first vertex at [startDeg].
  Path _regularPolygon(Rect rect, int sides, double startDeg) {
    final Offset c = rect.center;
    final double r = rect.shortestSide / 2;
    final Path path = Path();
    for (int i = 0; i < sides; i++) {
      final double angle = (startDeg + i * (360 / sides)) * math.pi / 180;
      final Offset p = Offset(
        c.dx + r * math.cos(angle),
        c.dy + r * math.sin(angle),
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_CubeFacePainter old) =>
      old.shape != shape ||
      old.n != n ||
      old.color != color ||
      old.badge != badge;
}
