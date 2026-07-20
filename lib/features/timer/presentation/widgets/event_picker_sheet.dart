import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/wca_event.dart';

/// Maps a domain [PuzzleFamily] onto the icon's [PuzzleShape].
///
/// The mapping lives here rather than in either layer because it is the seam
/// between them: `core/widgets` must not know about events, and the domain
/// must not import Flutter.
PuzzleShape shapeFor(WcaEvent event) => switch (event.family) {
      PuzzleFamily.cube => PuzzleShape.nxn,
      PuzzleFamily.dodecahedron => PuzzleShape.pentagon,
      PuzzleFamily.tetrahedron => PuzzleShape.triangle,
      PuzzleFamily.skewb => PuzzleShape.skewb,
      PuzzleFamily.square1 => PuzzleShape.square1,
      PuzzleFamily.clock => PuzzleShape.clock,
    };

/// Maps a domain [PuzzleModifier] onto the icon's [PuzzleBadge].
PuzzleBadge badgeFor(WcaEvent event) => switch (event.modifier) {
      PuzzleModifier.none => PuzzleBadge.none,
      PuzzleModifier.blindfolded => PuzzleBadge.blindfolded,
      PuzzleModifier.oneHanded => PuzzleBadge.oneHanded,
      PuzzleModifier.fewestMoves => PuzzleBadge.fewestMoves,
      PuzzleModifier.multiBlind => PuzzleBadge.multiBlind,
    };

/// The composed icon for an event — base shape plus discipline badge.
class EventIcon extends StatelessWidget {
  const EventIcon({
    super.key,
    required this.event,
    this.size = 24,
    this.active = false,
    this.color,
  });

  final WcaEvent event;
  final double size;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) => CubeFaceIcon(
        shape: shapeFor(event),
        n: (event.cubeSize ?? 3).clamp(2, 9),
        badge: badgeFor(event),
        size: size,
        active: active,
        color: color,
      );
}

/// The event picker.
///
/// **A seventeen-item bottom sheet is not a picker**, so this is not one:
///
///   * **Grouped** — Cubes · Other puzzles · Blindfolded · Special, the order a
///     cuber looks for them in, so the list is four short lists rather than
///     one long one.
///   * **Search**, because seventeen is past the point where scanning beats
///     typing, and because cubers know the short names (`3BLD`, `OH`, `FMC`)
///     better than the full ones — so the query matches both.
///   * **Recents** pinned to the top, because practice is bursty: someone
///     drilling 3×3 and OH alternates between two events all session and
///     should not scroll for either.
///
/// There is no Figma frame for this screen — the file's Timer Home frames
/// predate multi-event support, and the MCP has no picker node. Composed from
/// the design tokens and the existing sheet pattern instead.
///
/// No event is hidden or disabled. An event without a scrambler is still fully
/// timeable, so it lists normally with a "no scrambles yet" note rather than
/// greyed out — a disabled row would say "you cannot use this", which is not
/// true.
class EventPickerSheet extends StatefulWidget {
  const EventPickerSheet({
    super.key,
    required this.selected,
    required this.recents,
    required this.onSelected,
  });

  /// Currently selected event id.
  final String selected;

  /// Recently used event ids, most recent first.
  final List<String> recents;

  final ValueChanged<String> onSelected;

  /// Opens the picker.
  static Future<void> show(
    BuildContext context, {
    required String selected,
    required List<String> recents,
    required ValueChanged<String> onSelected,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: context.colors.bgSurface,
        // Seventeen events across four groups will not fit a min-height sheet,
        // and the search field needs the keyboard not to cover the results.
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        builder: (BuildContext sheetContext) => EventPickerSheet(
          selected: selected,
          recents: recents,
          onSelected: (String id) {
            Navigator.of(sheetContext).pop();
            onSelected(id);
          },
        ),
      );

  @override
  State<EventPickerSheet> createState() => _EventPickerSheetState();
}

class _EventPickerSheetState extends State<EventPickerSheet> {
  String _query = '';

  /// Matches the full name, the short name and the id, because a cuber
  /// searching for 3×3 Blindfolded is as likely to type `3bld` or `bld` as
  /// `blindfolded`.
  bool _matches(WcaEvent event) {
    if (_query.isEmpty) return true;
    final String q = _query.toLowerCase();
    return event.name.toLowerCase().contains(q) ||
        event.shortName.toLowerCase().contains(q) ||
        event.id.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool searching = _query.isNotEmpty;

    final List<WcaEvent> recents = <WcaEvent>[
      for (final String id in widget.recents)
        if (WcaEvent.isKnown(id)) WcaEvent.fromId(id),
    ].where((WcaEvent e) => e.id != widget.selected).take(3).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController controller) => SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Event',
                    style:
                        AppTypography.title.copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Search',
                    hintText: 'Try “3bld”, “OH”, “mega”',
                    onChanged: (String value) =>
                        setState(() => _query = value.trim()),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                children: <Widget>[
                  if (!searching && recents.isNotEmpty) ...<Widget>[
                    const _GroupHeader('Recent'),
                    for (final WcaEvent event in recents) _row(event),
                  ],
                  for (final EventGroup group in EventGroup.values)
                    ..._group(group),
                  if (searching && !WcaEvent.all.any(_matches))
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'No event matches “$_query”.',
                        style: AppTypography.small
                            .copyWith(color: colors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _group(EventGroup group) {
    final List<WcaEvent> events =
        WcaEvent.inGroup(group).where(_matches).toList();
    if (events.isEmpty) return const <Widget>[];
    return <Widget>[
      _GroupHeader(group.label),
      for (final WcaEvent event in events) _row(event),
    ];
  }

  Widget _row(WcaEvent event) => _EventRow(
        event: event,
        selected: event.id == widget.selected,
        onTap: () => widget.onSelected(event.id),
      );
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        child: Text(
          label.toUpperCase(),
          style: AppTypography.overline
              .copyWith(color: context.colors.textSecondary),
        ),
      );
}

class _EventRow extends StatelessWidget {
  const _EventRow({
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

    // The subtitle earns its place: the competition format is the thing that
    // changes what the screen will show once you pick, and "no scrambles yet"
    // is the one caveat worth knowing before you commit to the event.
    final String subtitle = event.hasScrambler
        ? event.format.description
        : '${event.format.description} · no scrambles yet';

    return Semantics(
      button: true,
      selected: selected,
      label: '${event.name}, $subtitle',
      excludeSemantics: true,
      child: ListTile(
        onTap: onTap,
        leading: EventIcon(event: event, active: selected),
        title: Text(
          event.name,
          style: AppTypography.body.copyWith(
            color: selected ? colors.brandPrimary : colors.textPrimary,
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.caption.copyWith(color: colors.textSecondary),
        ),
        trailing: selected
            ? Icon(Icons.check, color: colors.brandPrimary)
            : Text(
                event.shortName,
                style: AppTypography.caption.copyWith(color: colors.textMuted),
              ),
      ),
    );
  }
}
