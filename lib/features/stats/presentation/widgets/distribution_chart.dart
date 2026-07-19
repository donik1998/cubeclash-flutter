import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/player_stats.dart';

/// Solve-time distribution — how many solves landed in each one-second bucket.
///
/// More useful than an average for a cuber: it shows *consistency*. A tall
/// narrow shape means a reliable solver; a long right tail means the occasional
/// disaster is what's holding the average back.
///
/// Bars grow on load (design system motion spec), staggered left to right, and
/// appear instantly under reduced motion.
class DistributionChart extends StatefulWidget {
  const DistributionChart({super.key, required this.buckets});

  final List<HistogramBucket> buckets;

  @override
  State<DistributionChart> createState() => _DistributionChartState();
}

class _DistributionChartState extends State<DistributionChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
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

    if (widget.buckets.isEmpty) return const SizedBox.shrink();

    final int peak = widget.buckets
        .map((HistogramBucket b) => b.count)
        .reduce((int a, int b) => a > b ? a : b);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'DISTRIBUTION',
            style: AppTypography.overline.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 140,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (int i = 0; i < widget.buckets.length; i++)
                    Expanded(
                      child: _Bar(
                        bucket: widget.buckets[i],
                        peak: peak,
                        // Stagger: each bar starts a little after the last.
                        grow: reduceMotion
                            ? 1
                            : _staggered(i, widget.buckets.length),
                        isPeak: widget.buckets[i].count == peak,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                TimeText.format(widget.buckets.first.fromMs),
                style: AppTypography.caption.copyWith(color: colors.textMuted),
              ),
              Text(
                TimeText.format(widget.buckets.last.toMs),
                style: AppTypography.caption.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bar [i]'s own 0→1 progress, offset so the chart sweeps rather than
  /// inflating all at once. Every bar still finishes by the time the controller
  /// does.
  double _staggered(int i, int count) {
    const double window = 0.6;
    final double start = count <= 1 ? 0 : (1 - window) * (i / (count - 1));
    return ((_controller.value - start) / window).clamp(0.0, 1.0);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.bucket,
    required this.peak,
    required this.grow,
    required this.isPeak,
  });

  final HistogramBucket bucket;
  final int peak;
  final double grow;
  final bool isPeak;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double fraction = peak == 0 ? 0 : bucket.count / peak;

    return Semantics(
      label: '${bucket.count} solves between '
          '${TimeText.format(bucket.fromMs)} and '
          '${TimeText.format(bucket.toMs)} seconds',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            // A minimum height so a bucket with one solve still reads as
            // "something happened here" rather than nothing.
            FractionallySizedBox(
              widthFactor: 1,
              child: Container(
                height: (8 + (140 - 24) * fraction) * grow,
                decoration: BoxDecoration(
                  color: isPeak
                      ? colors.brandPrimary
                      : colors.brandPrimary.withValues(alpha: 0.45),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.sm),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
