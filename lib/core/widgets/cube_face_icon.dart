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
}

/// Event icon, per the design system's iconography rules: line art, stroke 2,
/// round caps and joins, tinted `brand/primary` when active and `text/muted`
/// when not.
///
/// For [PuzzleShape.nxn] the grid density encodes the puzzle: [n] of 3 draws a
/// 3×3 face, [n] of 4 a 4×4, and so on.
class CubeFaceIcon extends StatelessWidget {
  const CubeFaceIcon({
    super.key,
    this.shape = PuzzleShape.nxn,
    this.n = 3,
    this.size = 24,
    this.active = false,
    this.color,
  }) : assert(n >= 2 && n <= 9, 'NxN icons are defined for 2×2 … 9×9');

  /// Convenience: the icon for an event string (`3x3`, `megaminx`, …).
  factory CubeFaceIcon.forEvent(
    String event, {
    Key? key,
    double size = 24,
    bool active = false,
    Color? color,
  }) {
    final String e = event.toLowerCase().trim();
    if (e == 'megaminx' || e == 'teraminx') {
      return CubeFaceIcon(
        key: key,
        shape: PuzzleShape.pentagon,
        size: size,
        active: active,
        color: color,
      );
    }
    if (e == 'pyraminx') {
      return CubeFaceIcon(
        key: key,
        shape: PuzzleShape.triangle,
        size: size,
        active: active,
        color: color,
      );
    }
    // `3x3` / `4x4` / … — fall back to 3 for anything unrecognised.
    final int parsed = int.tryParse(e.split('x').first) ?? 3;
    return CubeFaceIcon(
      key: key,
      n: parsed.clamp(2, 9),
      size: size,
      active: active,
      color: color,
    );
  }

  final PuzzleShape shape;
  final int n;
  final double size;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Color tint =
        color ?? (active ? colors.brandPrimary : colors.textMuted);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CubeFacePainter(shape: shape, n: n, color: tint),
      ),
    );
  }
}

class _CubeFacePainter extends CustomPainter {
  const _CubeFacePainter({
    required this.shape,
    required this.n,
    required this.color,
  });

  final PuzzleShape shape;
  final int n;
  final Color color;

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
    final Rect inset = bounds.deflate(stroke / 2);

    switch (shape) {
      case PuzzleShape.nxn:
        _paintGrid(canvas, inset, paint, stroke);
      case PuzzleShape.pentagon:
        canvas.drawPath(_regularPolygon(inset, 5, -90), paint);
      case PuzzleShape.triangle:
        canvas.drawPath(_regularPolygon(inset, 3, -90), paint);
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
      old.shape != shape || old.n != n || old.color != color;
}
