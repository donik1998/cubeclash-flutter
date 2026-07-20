import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/race_room.dart';
import '../bloc/race_bloc.dart';
import '../widgets/race_versus.dart';

/// The in-race screen — `/race/live`, **full-screen and outside the shell**.
///
/// Five phases share one layout ([RaceVersusScaffold]): the ready check, the
/// countdown, the solve, the wait for the opponent, and the settled result.
/// The Figma frames draw them as one screen whose lower half swaps, so that is
/// how they are built — the two clocks never move.
///
/// The ready check lives here rather than in the Race tab because the frame
/// gives it this screen's chrome and no nav bar: once you are matched with
/// someone, wandering off via a tab strands them.
class LiveRacePage extends StatelessWidget {
  const LiveRacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RaceBloc>.value(
      value: sl<RaceBloc>(),
      child: const _LiveRaceView(),
    );
  }
}

class _LiveRaceView extends StatelessWidget {
  const _LiveRaceView();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return BlocConsumer<RaceBloc, RaceState>(
      listenWhen: (RaceState a, RaceState b) => a.phase != b.phase,
      listener: (BuildContext context, RaceState state) {
        // Back to the lobby once the race is done with.
        if (state.phase == RacePhase.idle && context.canPop()) context.pop();
      },
      builder: (BuildContext context, RaceState state) {
        return PopScope(
          // No escape mid-solve. Leaving a live race has to be deliberate, and
          // the × in the header is where you leave from.
          // Back is blocked mid-race, but never in a way that can strand
          // the user — see RaceState.canLeave.
          canPop: state.canLeave,
          child: Scaffold(
            backgroundColor: colors.bgCanvas,
            body: SafeArea(
              child: switch (state.phase) {
                RacePhase.readyCheck =>
                  _InRace(state: state, stage: _Ready(state: state)),
                RacePhase.countdown =>
                  _InRace(state: state, stage: _Countdown(state: state)),
                RacePhase.racing => _Racing(state: state),
                RacePhase.submitted =>
                  _InRace(state: state, stage: _Waiting(state: state)),
                RacePhase.settled => _Settled(state: state),
                // Any other phase here means the race ended from under us.
                _ => const LoadingState(),
              },
            ),
          ),
        );
      },
    );
  }
}

/// Binds [RaceVersusScaffold] to the bloc state for every phase but the
/// settled one, which has its own times and highlighting.
class _InRace extends StatelessWidget {
  const _InRace({required this.state, required this.stage});

  final RaceState state;
  final Widget stage;

  @override
  Widget build(BuildContext context) {
    final RaceBloc bloc = context.read<RaceBloc>();
    final RacePlayer? them = state.opponent;

    // Nobody has a time until the solve starts. Reading the room's progress
    // before then would surface a stale value from the previous race — the
    // frames show 0.00 / 0.00 through the ready check and countdown, and that
    // is also the only honest thing to show.
    final bool started =
        state.phase == RacePhase.racing || state.phase == RacePhase.submitted;

    return RaceVersusScaffold(
      you: state.you,
      opponent: them,
      scramble: state.scramble,
      // Your own clock: live while solving, frozen at your submitted time once
      // you've stopped.
      yourTimeMs: !started
          ? null
          : state.phase == RacePhase.racing
              ? state.elapsed.inMilliseconds
              : state.yourTimeMs,
      opponentTimeMs: started ? (them?.finalTimeMs ?? them?.progressMs) : null,
      banner: state.disconnected ? const _ConnectionBanner() : null,
      // Leaving is only offered where it is actually possible. During the
      // countdown and the solve the race is in flight — that is precisely what
      // the PopScope above is guarding — and while racing the whole surface is
      // the stop button anyway, so a × there could never be tapped.
      //
      // Once submitted-and-overdue, the exit comes back: your time is already
      // with the server, you are only waiting to be told the outcome, and
      // without this there is no way off the screen at all.
      onClose: switch (state.phase) {
        RacePhase.readyCheck => () => bloc.add(const RaceCancelled()),
        // Dismiss, not cancel: the submitted time stands and the server still
        // settles the race — leaving the screen must not retract it.
        RacePhase.submitted when state.resultOverdue => () =>
            bloc.add(const RaceDismissed()),
        _ => null,
      },
      stage: stage,
    );
  }
}

// --- Ready check -------------------------------------------------------------

class _Ready extends StatelessWidget {
  const _Ready({required this.state});

  final RaceState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final RaceBloc bloc = context.read<RaceBloc>();
    final bool youReady = state.you?.ready ?? false;
    final RacePlayer? them = state.opponent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'READY UP?',
          style: AppTypography.overline.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _ReadyChip(
              label: youReady ? 'You: ready' : 'You: not ready',
              ready: youReady,
            ),
            if (them != null)
              _ReadyChip(
                label: them.ready
                    ? '${them.displayName}: ready'
                    : '${them.displayName}: not ready',
                ready: them.ready,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: youReady ? 'Waiting for them…' : "I'm ready",
          expand: false,
          onPressed: youReady ? null : () => bloc.add(const RaceReadyPressed()),
        ),
      ],
    );
  }
}

class _ReadyChip extends StatelessWidget {
  const _ReadyChip({required this.label, required this.ready});

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.bgSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Text(
        label,
        style: AppTypography.pillLabel.copyWith(
          color: ready ? colors.statusSuccess : colors.textSecondary,
        ),
      ),
    );
  }
}

// --- Countdown ---------------------------------------------------------------

class _Countdown extends StatelessWidget {
  const _Countdown({required this.state});

  final RaceState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final int n = state.countdown ?? 3;

    return Text(
      n == 0 ? 'GO' : '$n',
      // The key restarts the scale-in on every tick, so each number punches
      // rather than crossfading into the last.
      key: ValueKey<int>(n),
      style: AppTypography.display.copyWith(
        fontSize: 96,
        color: n == 0 ? colors.statusSuccess : colors.textPrimary,
      ),
    );
  }
}

// --- Racing ------------------------------------------------------------------

class _Racing extends StatelessWidget {
  const _Racing({required this.state});

  final RaceState state;

  @override
  Widget build(BuildContext context) {
    final RaceBloc bloc = context.read<RaceBloc>();

    return Listener(
      behavior: HitTestBehavior.opaque,
      // Stop on press, as on the solo timer — a solve ends when the hands land.
      onPointerDown: (_) {
        HapticFeedback.selectionClick();
        bloc.add(const RaceSolveStopped());
      },
      child: _InRace(
        state: state,
        stage: Text(
          'Tap anywhere to stop',
          style: AppTypography.stagePrompt
              .copyWith(color: context.colors.textSecondary),
        ),
      ),
    );
  }
}

// --- Submitted, waiting on the opponent --------------------------------------

class _Waiting extends StatelessWidget {
  const _Waiting({required this.state});

  final RaceState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool dropped = state.opponentReconnecting;

    final bool overdue = state.resultOverdue;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          overdue
              ? "We've lost touch with the race"
              : dropped
                  ? 'Your opponent dropped — waiting for them to reconnect'
                  : 'Waiting for your opponent to finish',
          textAlign: TextAlign.center,
          style: AppTypography.stagePrompt.copyWith(
            color: overdue || dropped
                ? colors.statusWarning
                : colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          overdue
              // Reassure precisely: the time is already server-side, so
              // leaving costs nothing. Without saying so, the exit reads as
              // "forfeit" and nobody takes it.
              ? 'Your time is already submitted and will still count. '
                  'You can leave and check the result later.'
              : 'The server decides the result.',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: colors.textMuted),
        ),
        if (overdue) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          AppButton.secondary(
            label: 'Back to lobby',
            expand: false,
            onPressed: () =>
                context.read<RaceBloc>().add(const RaceDismissed()),
          ),
        ],
      ],
    );
  }
}

// --- Settled -----------------------------------------------------------------

class _Settled extends StatelessWidget {
  const _Settled({required this.state});

  final RaceState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final RaceBloc bloc = context.read<RaceBloc>();
    final RaceResult? result = state.result;

    if (result == null) return const LoadingState();

    final (String headline, Color accent) = switch (result.outcome) {
      RaceOutcome.win => ('YOU WIN', colors.statusSuccess),
      RaceOutcome.loss => ('YOU LOSE', colors.statusDanger),
      RaceOutcome.dnf => ('NO RESULT', colors.statusWarning),
      RaceOutcome.left => ('YOU LEFT', colors.statusDanger),
    };

    // Straight off `race:result`. The client never works out who won.
    final RaceVersusSide? winner = switch (result.outcome) {
      RaceOutcome.win => RaceVersusSide.you,
      RaceOutcome.loss => RaceVersusSide.opponent,
      _ => null,
    };

    return RaceVersusScaffold(
      you: state.you,
      opponent: state.opponent,
      scramble: state.scramble,
      yourTimeMs: result.yourTimeMs,
      opponentTimeMs: result.opponentTimeMs,
      yourDnf: result.yourDnf,
      opponentDnf: result.opponentDnf || result.opponentLeft,
      winner: winner,
      onClose: () => bloc.add(const RaceDismissed()),
      stage: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            headline,
            textAlign: TextAlign.center,
            style: AppTypography.resultHeadline.copyWith(color: accent),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Scoreline(result: result),
          if (result.opponentLeft) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your opponent disconnected.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: colors.textMuted),
            ),
          ],
          if (result.eloDelta case final int elo) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            // Server-supplied. The client never computes a rating change.
            AppChip(
              label: '${elo >= 0 ? '+' : ''}$elo Elo',
              variant: elo >= 0 ? AppChipVariant.event : AppChipVariant.dnf,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppButton(
                label: 'Rematch',
                expand: false,
                onPressed: () => bloc.add(const RaceRematchRequested()),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton.secondary(
                label: 'Lobby',
                expand: false,
                onPressed: () => bloc.add(const RaceDismissed()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `8.42s  vs  8.77s` (Figma `34:194`).
class _Scoreline extends StatelessWidget {
  const _Scoreline({required this.result});

  final RaceResult result;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    String side(int? ms, bool dnf) =>
        dnf || ms == null ? 'DNF' : '${TimeText.format(ms)}s';

    return Text(
      '${side(result.yourTimeMs, result.yourDnf)}   vs   '
      '${side(result.opponentTimeMs, result.opponentDnf || result.opponentLeft)}',
      textAlign: TextAlign.center,
      style: AppTypography.versusName
          .copyWith(color: colors.textSecondary, fontWeight: FontWeight.w500)
          .tabular,
    );
  }
}

/// Shown when your own socket is down. Deliberately reassuring: the solve is
/// still being timed locally and the room is held server-side.
class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.statusWarning.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.wifi_off, size: 16, color: colors.statusWarning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Reconnecting — your time is still being recorded.',
              style:
                  AppTypography.caption.copyWith(color: colors.statusWarning),
            ),
          ),
        ],
      ),
    );
  }
}
