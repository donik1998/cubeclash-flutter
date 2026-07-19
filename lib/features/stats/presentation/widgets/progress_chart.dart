import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/player_stats.dart';

/// Solve times over the last few weeks — daily average as a line, daily best as
/// a second, faster line beneath it.
///
/// Hand-painted rather than pulling in a charting package: the design system
/// wants two token-coloured lines and nothing else, and a chart library would
/// bring a theming layer to fight with for features we don't use.
///
/// **The y-axis is inverted** — faster is up. A speedcubing progress chart that
/// slopes downward as you improve reads as failure at a glance, which is
/// exactly backwards.
///
/// Draws in on load, per the design system's motion spec, and crossfades
/// instead when the user has asked for reduced motion.
class ProgressChart extends StatefulWidget {
  const ProgressChart({super.key, required this.points});

  /// Oldest first.
  final List<StatsPoint> points;

  @override
  State<ProgressChart> createState() => _ProgressChartState();
}

class _ProgressChartState extends State<ProgressChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (widget.points.length < 2) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'PROGRESS',
            style: AppTypography.overline.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              _Legend(color: colors.brandPrimary, label: 'Daily average'),
              const SizedBox(width: AppSpacing.lg),
              _Legend(color: colors.accentEnergy, label: 'Daily best'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 160,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, _) => CustomPaint(
                size: Size.infinite,
                painter: _ProgressPainter(
                  points: widget.points,
                  // Reduced motion: draw the whole line immediately and let
                  // the card's own fade carry the entrance.
                  progress: reduceMotion ? 1 : _controller.value,
                  averageColor: colors.brandPrimary,
                  bestColor: colors.accentEnergy,
                  gridColor: colors.borderSubtle,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _shortDate(widget.points.first.day),
                style: AppTypography.caption.copyWith(color: colors.textMuted),
              ),
              Text(
                _shortDate(widget.points.last.day),
                style: AppTypography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _shortDate(DateTime day) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${day.day} ${months[day.month - 1]}';
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption
                .copyWith(color: context.colors.textSecondary),
          ),
        ],
      );
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({
    required this.points,
    required this.progress,
    required this.averageColor,
    required this.bestColor,
    required this.gridColor,
  });

  final List<StatsPoint> points;

  /// 0 → 1 draw-in.
  final double progress;
  final Color averageColor;
  final Color bestColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    // A shared scale across both series, so "the best line sits below the
    // average line" stays literally true.
    int minMs = points.first.bestMs;
    int maxMs = points.first.averageMs;
    for (final StatsPoint p in points) {
      if (p.bestMs < minMs) minMs = p.bestMs;
      if (p.averageMs > maxMs) maxMs = p.averageMs;
    }
    // Breathing room, and a guard against a flat series dividing by zero.
    final double span = (maxMs - minMs).toDouble();
    final double padded = span < 1 ? 1000 : span * 1.15;
    final double base = minMs - (padded - span) / 2;

    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final double y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    _drawSeries(
      canvas,
      size,
      values: points.map((StatsPoint p) => p.averageMs).toList(),
      base: base,
      padded: padded,
      color: averageColor,
      fill: true,
    );
    _drawSeries(
      canvas,
      size,
      values: points.map((StatsPoint p) => p.bestMs).toList(),
      base: base,
      padded: padded,
      color: bestColor,
      fill: false,
    );
  }

  void _drawSeries(
    Canvas canvas,
    Size size, {
    required List<int> values,
    required double base,
    required double padded,
    required Color color,
    required bool fill,
  }) {
    // Inverted: a smaller time maps to a higher point.
    Offset pointAt(int index) {
      final double x =
          values.length == 1 ? 0 : size.width * (index / (values.length - 1));
      final double t = ((values[index] - base) / padded).clamp(0.0, 1.0);
      return Offset(x, size.height * t);
    }

    // Reveal left to right; the partial segment interpolates so the line grows
    // smoothly rather than snapping point to point.
    final double exact = (values.length - 1) * progress;
    final int whole = exact.floor();
    final double fraction = exact - whole;

    final Path path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (int i = 1; i <= whole; i++) {
      final Offset p = pointAt(i);
      path.lineTo(p.dx, p.dy);
    }
    if (whole < values.length - 1 && fraction > 0) {
      final Offset from = pointAt(whole);
      final Offset to = pointAt(whole + 1);
      path.lineTo(
        from.dx + (to.dx - from.dx) * fraction,
        from.dy + (to.dy - from.dy) * fraction,
      );
    }

    if (fill) {
      final Path area = Path.from(path)
        ..lineTo(path.getBounds().right, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.progress != progress ||
      old.points != points ||
      old.averageColor != averageColor;
}
