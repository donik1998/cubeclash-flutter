import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/scramble_source.dart';

/// The scramble card — Figma `Timer Home → scramble` (node `21:62`).
///
/// Three parts, top to bottom: a source segmented control, the scramble itself,
/// and a footer pairing the source caption with a `New` pill.
///
/// The scramble sits at 19/28 Medium rather than the design system's `Small`
/// role — this is the one place a cuber reads mid-turn, so the frame gives it
/// its own size. Moves wrap on token boundaries because a scramble broken
/// mid-move (`R2` split across lines) is genuinely misleading.
class ScrambleCard extends StatelessWidget {
  const ScrambleCard({
    super.key,
    required this.scramble,
    required this.source,
    required this.onNewScramble,
    required this.onSourceChanged,
  });

  final String scramble;
  final ScrambleSource source;
  final VoidCallback onNewScramble;
  final ValueChanged<ScrambleSource> onSourceChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSegmentedControl(
            segments: ScrambleSource.values
                .map((ScrambleSource s) => s.label)
                .toList(),
            selectedIndex: source.index,
            onChanged: (int i) => onSourceChanged(ScrambleSource.values[i]),
          ),
          const SizedBox(height: AppSpacing.md),
          if (source.isAvailable)
            Text(
              scramble,
              style: AppTypography.scramble.copyWith(color: colors.textPrimary),
              semanticsLabel: 'Scramble: ${scramble.split(' ').join(', ')}',
            )
          else
            _Unavailable(source: source),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  source.caption,
                  style:
                      AppTypography.caption.copyWith(color: colors.textMuted),
                ),
              ),
              _NewButton(
                onPressed: source.isAvailable ? onNewScramble : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown for a source the MVP can't serve.
///
/// Says so plainly instead of falling back to a random scramble under a WCA
/// label — the control exists to communicate provenance, so a silent fallback
/// would defeat its only purpose.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.source});

  final ScrambleSource source;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        source == ScrambleSource.wca
            ? 'Scrambles from real WCA rounds are coming. Random scrambles '
                'are WCA-legal in the meantime.'
            : 'Solve something first and it will show up here.',
        style: AppTypography.small.copyWith(color: colors.textSecondary),
      ),
    );
  }
}

/// The `New` pill — Figma `26:40`.
class _NewButton extends StatelessWidget {
  const _NewButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'New scramble',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: colors.bgSurfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Padding(
              // The frame's 10×6 padding gives a 28pt-tall pill. Padded out to
              // a 44pt hit box below so the target clears guidance without
              // changing what's drawn.
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AppIcon(
                    AppIcons.refresh,
                    size: 13,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'New',
                    style: AppTypography.caption
                        .copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
