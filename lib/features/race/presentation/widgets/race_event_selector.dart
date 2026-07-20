import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../timer/domain/entities/wca_event.dart';
import '../../../timer/presentation/widgets/event_picker_sheet.dart';

/// Picks the event for a race.
///
/// ## Which events are raceable, and why the two lists differ
///
/// A race needs a scramble both players get, a result the client can measure
/// and submit the instant it lands, and a solve short enough that two people
/// will both sit through it. That rules out the five events with no scrambler,
/// Fewest Moves (the result is a written solution, not a time), Multi-Blind
/// (an hour), and the blindfolded events — whose memorisation phase is inside
/// the timed attempt, so nothing on screen can tell concentrating from
/// stalling. See `WcaEvent.raceableEvents`.
///
/// **Quick match is narrower still.** Matchmaking on `6×6 quick match` would
/// sit in the search screen forever, because the pool for it is realistically
/// empty — nobody queues at random for a two-minute solve. So quick match
/// offers only where the population is (`WcaEvent.quickMatchEvents`), and
/// everything else raceable is available in a private room, where you already
/// know somebody is on the other side and willing.
class RaceEventSelector extends StatelessWidget {
  const RaceEventSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.quickMatchOnly = false,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  /// Restricts the list to [WcaEvent.quickMatchEvents].
  final bool quickMatchOnly;

  List<WcaEvent> get _events =>
      quickMatchOnly ? WcaEvent.quickMatchEvents : WcaEvent.raceableEvents;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Event',
          style: AppTypography.overline.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final WcaEvent event in _events)
              _EventPill(
                event: event,
                selected: event.id == selected,
                onTap: () => onChanged(event.id),
              ),
          ],
        ),
        if (quickMatchOnly) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Longer events are private-room only — there is no queue to match '
            'you into.',
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _EventPill extends StatelessWidget {
  const _EventPill({
    required this.event,
    required this.selected,
    required this.onTap,
  });

  final WcaEvent event;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(AppRadius.pill);

    return Semantics(
      button: true,
      selected: selected,
      label: event.name,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.brandPrimarySoft : colors.bgSurfaceAlt,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                EventIcon(
                  event: event,
                  size: 15,
                  color: selected ? colors.brandPrimary : colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  event.shortName,
                  style: AppTypography.caption.copyWith(
                    color:
                        selected ? colors.brandPrimary : colors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
