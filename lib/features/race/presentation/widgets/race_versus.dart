import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/country_names.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/race_room.dart';

/// The chrome shared by every in-race screen — ready room, countdown, the live
/// solve and both result states (Figma `34:106`, `34:140`, `34:167`, `39:106`).
///
/// Those four frames are **one screen**, not four: the same `LIVE RACE` header,
/// the same two player cards, the same scramble line. Only [stage] — the
/// flexible region filling the lower half — changes between them. Building it
/// that way is not just DRY: the two clocks holding still while the stage
/// swaps underneath is what makes the whole thing read as one continuous race
/// rather than a sequence of separate screens.
class RaceVersusScaffold extends StatelessWidget {
  const RaceVersusScaffold({
    super.key,
    required this.you,
    required this.opponent,
    required this.stage,
    this.onClose,
    this.scramble = '',
    this.yourTimeMs,
    this.opponentTimeMs,
    this.yourDnf = false,
    this.opponentDnf = false,
    this.winner,
    this.banner,
  });

  final RacePlayer? you;
  final RacePlayer? opponent;

  /// Fills the remaining height, centred. The only part that varies by phase.
  final Widget stage;

  /// Leaves the race. Omitted once there is nothing left to leave.
  final VoidCallback? onClose;

  /// Rendered only when non-empty — the server withholds the scramble until GO,
  /// so before then there is genuinely nothing to show. See the note in
  /// [RaceScrambleBlock].
  final String scramble;

  final int? yourTimeMs;
  final int? opponentTimeMs;
  final bool yourDnf;
  final bool opponentDnf;

  /// Which side the **server** declared the winner, or null while undecided.
  ///
  /// Never derived here by comparing the two times — see `RaceResult`.
  final RaceVersusSide? winner;

  /// Optional strip below the header, e.g. the reconnecting notice.
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        RaceLiveHeader(onClose: onClose),
        if (banner != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              0,
            ),
            child: banner,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            6,
            AppSpacing.xl,
            AppSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: RaceVersusCard(
                  player: you,
                  timeMs: yourTimeMs,
                  isDnf: yourDnf,
                  won: winner == RaceVersusSide.you,
                  lost: winner == RaceVersusSide.opponent,
                ),
              ),
              const _VersusJoin(),
              Expanded(
                child: RaceVersusCard(
                  player: opponent,
                  timeMs: opponentTimeMs,
                  isDnf: opponentDnf,
                  won: winner == RaceVersusSide.opponent,
                  lost: winner == RaceVersusSide.you,
                ),
              ),
            ],
          ),
        ),
        RaceScrambleBlock(scramble: scramble),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Center(child: stage),
          ),
        ),
      ],
    );
  }
}

/// Which of the two seats a result refers to.
enum RaceVersusSide { you, opponent }

/// `● LIVE RACE` with a close affordance (Figma `34:144`).
class RaceLiveHeader extends StatelessWidget {
  const RaceLiveHeader({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, AppSpacing.md, 22, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.statusDanger,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'LIVE RACE',
                style: AppTypography.liveOverline
                    .copyWith(color: colors.statusDanger),
              ),
            ],
          ),
          if (onClose != null) _CloseButton(onPressed: onClose!),
        ],
      ),
    );
  }
}

/// The frame draws a bare 22pt `×`. A 22pt glyph is nowhere near a 48dp target,
/// so the glyph keeps its size and the tap area is padded out around it.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Semantics(
      button: true,
      label: 'Leave race',
      child: InkResponse(
        onTap: onPressed,
        radius: 24,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Text(
              '×',
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w400,
              ).copyWith(color: colors.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}

class _VersusJoin extends StatelessWidget {
  const _VersusJoin();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Text(
        'VS',
        style:
            AppTypography.versusJoin.copyWith(color: context.colors.textMuted),
      ),
    );
  }
}

/// One player's card: avatar, name, country **in words**, and their clock
/// (Figma `34:150`).
///
/// Both cards render their time at the same size. That equality is the design:
/// there is no hero timer here, because a race is a comparison and sizing your
/// own clock larger would turn it back into a solo solve with a footnote.
class RaceVersusCard extends StatelessWidget {
  const RaceVersusCard({
    super.key,
    required this.player,
    this.timeMs,
    this.isDnf = false,
    this.won = false,
    this.lost = false,
  });

  final RacePlayer? player;

  /// Null renders `0.00` — a race that hasn't started still shows two clocks.
  final int? timeMs;
  final bool isDnf;

  /// Server-declared. Draws the `status/success` outline.
  final bool won;

  /// Server-declared. Dims the card back.
  final bool lost;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final RacePlayer? p = player;

    // The winner's clock, and otherwise your own, reads at full strength; the
    // other side sits back in `text/secondary`.
    final bool strong = won || (!lost && (p?.isYou ?? false));

    final Widget card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.versusCard),
        border: Border.all(
          color: won ? colors.statusSuccess : colors.borderSubtle,
          width: won ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Avatar(player: p),
          const SizedBox(height: 7),
          Text(
            p == null ? 'Waiting…' : (p.isYou ? 'You' : p.displayName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.versusName.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 7),
          Text(
            _subtitle(p),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: p != null && !p.connected
                  ? colors.statusWarning
                  : colors.textSecondary,
            ),
          ),
          const SizedBox(height: 7),
          if (isDnf)
            Text(
              'DNF',
              style:
                  AppTypography.versusTime.copyWith(color: colors.statusDanger),
            )
          else
            TimeText(
              timeMs: timeMs ?? 0,
              style: AppTypography.versusTime,
              color: strong ? colors.textPrimary : colors.textSecondary,
            ),
        ],
      ),
    );

    // Losing dims the whole card rather than restyling each line inside it.
    return lost ? Opacity(opacity: 0.5, child: card) : card;
  }

  /// The country in words, per the frame. Falls back to the connection state,
  /// which is the more urgent thing to say when it applies, and to nothing at
  /// all when we know neither — an empty line beats an invented one.
  static String _subtitle(RacePlayer? p) {
    if (p == null) return 'Looking for an opponent';
    if (!p.connected) return 'Reconnecting…';
    return countryCodeToName(p.countryCode) ?? '';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.player});

  final RacePlayer? player;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final RacePlayer? p = player;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.bgSurfaceAlt,
      ),
      alignment: Alignment.center,
      child: Text(
        p == null || p.displayName.isEmpty
            ? '?'
            : p.displayName.characters.first.toUpperCase(),
        style: AppTypography.title.copyWith(color: colors.textSecondary),
      ),
    );
  }
}

/// `SAME SCRAMBLE` and the scramble itself (Figma `34:162`).
///
/// Renders nothing until there is a scramble to render. The Figma ready-room
/// frame shows one, but the race protocol reveals the scramble to both players
/// at GO and not before — `RaceState.scramble` is empty until then. Showing it
/// during the ready check would hand whoever opens the app first a head start,
/// which defeats the synchronised countdown the whole gateway exists to
/// provide. So the block appears on its own at GO rather than being faked
/// early.
class RaceScrambleBlock extends StatelessWidget {
  const RaceScrambleBlock({super.key, required this.scramble});

  final String scramble;

  @override
  Widget build(BuildContext context) {
    if (scramble.isEmpty) return const SizedBox.shrink();

    final AppColors colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        0,
      ),
      child: Column(
        children: <Widget>[
          Text(
            'SAME SCRAMBLE',
            style: AppTypography.overline.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 6),
          Text(
            scramble,
            textAlign: TextAlign.center,
            style: AppTypography.label.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
