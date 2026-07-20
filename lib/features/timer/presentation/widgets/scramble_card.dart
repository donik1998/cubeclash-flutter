import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/scramble.dart';
import '../../domain/entities/scramble_source.dart';
import '../../domain/entities/wca_event.dart';

/// The scramble card — Figma `Timer Home → scramble` (node `21:62`).
///
/// Three parts, top to bottom: a source segmented control, the scramble
/// itself, and a footer pairing the source caption with a `New` pill.
///
/// ## Why this is no longer a fixed block
///
/// The frame was drawn for a 3×3: twenty moves at 19/28, four lines, done. The
/// same card has to carry a 100-move 7×7 scramble, a seven-line Megaminx and
/// three separate Multi-Blind scrambles, so it adapts on two axes:
///
///   * **Type ramps by length** — 19/28 up to ~25 tokens, 16/24 to ~50, then
///     13/19. A 7×7 at the frame's size is ten lines and swallows the screen.
///   * **Past [_collapseAfterLines] rendered lines it collapses**, showing the
///     first few with an expander, rather than shrinking type past the point
///     of being readable at arm's length — which is the only thing this card
///     is for.
///
/// **Line breaks are structure, not wrapping.** Each [Scramble] line renders
/// as its own paragraph, so a Megaminx scramble keeps the seven lines cubers
/// execute it in, and Multi-Blind's separate scrambles never run together.
class ScrambleCard extends StatefulWidget {
  const ScrambleCard({
    super.key,
    required this.scramble,
    required this.event,
    required this.source,
    required this.onNewScramble,
    required this.onSourceChanged,
  });

  final Scramble scramble;
  final WcaEvent event;
  final ScrambleSource source;
  final VoidCallback onNewScramble;
  final ValueChanged<ScrambleSource> onSourceChanged;

  /// Beyond this many rendered lines the card collapses. Four is what the
  /// frame's 3×3 occupies, so anything the card was designed for still shows
  /// whole and only the genuinely long events collapse.
  static const int _collapseAfterLines = 4;

  @override
  State<ScrambleCard> createState() => _ScrambleCardState();
}

class _ScrambleCardState extends State<ScrambleCard> {
  bool _expanded = false;

  @override
  void didUpdateWidget(ScrambleCard old) {
    super.didUpdateWidget(old);
    // A new scramble collapses again — expansion is a decision about *this*
    // scramble, not a preference.
    if (old.scramble != widget.scramble) _expanded = false;
  }

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
            selectedIndex: widget.source.index,
            onChanged: (int i) =>
                widget.onSourceChanged(ScrambleSource.values[i]),
          ),
          const SizedBox(height: AppSpacing.md),
          _body(colors),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _caption,
                  style:
                      AppTypography.caption.copyWith(color: colors.textMuted),
                ),
              ),
              _NewButton(
                onPressed: _canScramble ? widget.onNewScramble : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A scramble can only be produced when the source can serve one *and* the
  /// event has a scrambler at all.
  bool get _canScramble =>
      widget.source.isAvailable && widget.event.hasScrambler;

  String get _caption {
    if (!widget.event.hasScrambler) return '${widget.event.name} scrambles';
    if (widget.scramble.isMultiScramble) {
      return '${widget.scramble.lines.length} cubes · '
          '${widget.source.caption.toLowerCase()}';
    }
    return widget.source.caption;
  }

  Widget _body(AppColors colors) {
    if (!widget.event.hasScrambler) {
      return _NoScrambler(event: widget.event);
    }
    if (!widget.source.isAvailable) {
      return _Unavailable(source: widget.source);
    }
    if (widget.scramble.isEmpty) {
      return _Unavailable(source: widget.source);
    }
    return _ScrambleBody(
      scramble: widget.scramble,
      expanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
    );
  }
}

/// The scramble text itself, with the length ramp and the collapse.
class _ScrambleBody extends StatelessWidget {
  const _ScrambleBody({
    required this.scramble,
    required this.expanded,
    required this.onToggle,
  });

  final Scramble scramble;
  final bool expanded;
  final VoidCallback onToggle;

  /// The type ramp. Measured against **tokens**, not characters, because a
  /// token is what wraps: 20 moves of 3×3 and 20 moves of 7×7 occupy the same
  /// number of lines even though the 7×7 tokens are longer.
  TextStyle get _style => switch (scramble.moveCount) {
        <= 25 => AppTypography.scramble,
        <= 50 => AppTypography.scrambleCompact,
        _ => AppTypography.scrambleDense,
      };

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final TextStyle style = _style.copyWith(color: colors.textPrimary);

    final List<List<String>> lines = scramble.lines;
    final bool collapsible =
        !expanded && lines.length > ScrambleCard._collapseAfterLines;
    final List<List<String>> shown = collapsible
        ? lines.take(ScrambleCard._collapseAfterLines).toList()
        : lines;
    final int hidden = lines.length - shown.length;

    return Semantics(
      label: scramble.semanticsLabel,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < shown.length; i++)
            Padding(
              // Megaminx's line breaks are the point — a little air between
              // them is what makes "line 3 of 7" findable at a glance.
              padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.xs),
              child: _ScrambleLine(
                tokens: shown[i],
                style: style,
                // Multi-Blind is N scrambles; numbering them is the only thing
                // that tells the user which cube each one is for.
                index: scramble.isMultiScramble ? i + 1 : null,
                notation: scramble.notation,
              ),
            ),
          if (collapsible || expanded) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _ExpandToggle(
              expanded: expanded,
              hiddenLines: hidden,
              onPressed: onToggle,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScrambleLine extends StatelessWidget {
  const _ScrambleLine({
    required this.tokens,
    required this.style,
    required this.notation,
    this.index,
  });

  final List<String> tokens;
  final TextStyle style;
  final ScrambleNotation notation;

  /// 1-based line number, for Multi-Blind only.
  final int? index;

  /// Zero-width space — an invisible break opportunity.
  ///
  /// Square-1 has no spaces to wrap on (`(1,0)/(6,0)/(-3,0)`), so without this
  /// the whole scramble is one unbreakable token that overflows the card. The
  /// break lands after a slash, which is where a solver pauses anyway.
  static const String _zwsp = '​';

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    final String text = switch (notation) {
      ScrambleNotation.slashPairs => tokens.join(_zwsp),
      // A single space, and wrapping happens on it — a move split across two
      // lines (`R` on one, `2` on the next) is genuinely misleading.
      _ => tokens.join(' '),
    };

    if (index == null) return Text(text, style: style);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 22,
          child: Text(
            '$index.',
            style: style.copyWith(color: colors.textMuted).tabular,
          ),
        ),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// `Show all 7 lines` / `Show less`.
class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({
    required this.expanded,
    required this.hiddenLines,
    required this.onPressed,
  });

  final bool expanded;
  final int hiddenLines;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final String label = expanded
        ? 'Show less'
        : 'Show $hiddenLines more line'
            '${hiddenLines == 1 ? '' : 's'}';

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: colors.brandPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppIcon(
                AppIcons.chevronDown,
                size: 9,
                color: colors.brandPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown for an event whose scrambler does not exist yet.
///
/// Five of the seventeen: Megaminx, Pyraminx, Skewb, Square-1 and Clock. Each
/// has its own notation and, for competition-legal scrambles, needs a
/// random-*state* solver. Saying so is the honest option — handing over a
/// sequence of 3×3 moves under a Megaminx label would be worse than useless,
/// because it would look right.
class _NoScrambler extends StatelessWidget {
  const _NoScrambler({required this.event});

  final WcaEvent event;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${event.name} scrambles are coming.',
            style: AppTypography.small.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'It needs its own notation and a solver to be WCA-legal. Time and '
            'track your solves here in the meantime — scramble by hand or from '
            'another source.',
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
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
