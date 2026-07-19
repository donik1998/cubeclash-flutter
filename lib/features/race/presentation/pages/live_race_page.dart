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
import '../widgets/race_widgets.dart';

/// Live Race — `/race/live`, **full-screen and outside the shell**.
///
/// A real route rather than a state of the lobby: this is a different screen
/// you are taken to, the nav bar must not exist while you're in it, and the
/// back gesture must not work mid-solve.
///
/// Renders four phases — countdown, racing, submitted (waiting on them), and
/// the settled result.
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
          // the result screen is where you leave from.
          canPop: state.phase == RacePhase.settled,
          child: Scaffold(
            backgroundColor: colors.bgCanvas,
            body: SafeArea(
              child: switch (state.phase) {
                RacePhase.countdown => _Countdown(state: state),
                RacePhase.racing => _Racing(state: state),
                RacePhase.submitted => _WaitingForOpponent(state: state),
                RacePhase.settled => _Result(state: state),
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

// --- Countdown ---------------------------------------------------------------

class _Countdown extends StatelessWidget {
  const _Countdown({required this.state});

  final RaceState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final int n = state.countdown ?? 3;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            n == 0 ? 'GO' : '$n',
            // The key restarts the scale-in on every tick, so each number
            // punches rather than crossfading into the last.
            key: ValueKey<int>(n),
            style: AppTypography.display.copyWith(
              fontSize: 120,
              color: n == 0 ? colors.statusSuccess : colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Same scramble for both of you',
            style: AppTypography.small.copyWith(color: colors.textMuted),
          ),
        ],
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
    final AppColors colors = context.colors;
    final RaceBloc bloc = context.read<RaceBloc>();

    return Listener(
      behavior: HitTestBehavior.opaque,
      // Stop on press, as on the solo timer — a solve ends when the hands land.
      onPointerDown: (_) {
        HapticFeedback.selectionClick();
        bloc.add(const RaceSolveStopped());
      },
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            if (state.disconnected) const _ConnectionBanner(),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'SCRAMBLE',
                    style: AppTypography.overline
                        .copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    state.scramble,
                    style: AppTypography.small.copyWith(
                      color: colors.textPrimary,
                      letterSpacing: 0.6,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: TimeText(
                  timeMs: state.elapsed.inMilliseconds,
                  style: AppTypography.display,
                ),
              ),
            ),
            OpponentProgressBar(
              opponent: state.opponent,
              yourElapsed: state.elapsed,
              reconnecting: state.opponentReconnecting,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Tap anywhere to stop',
              style: AppTypography.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// --- Submitted, waiting on the opponent --------------------------------------

class _WaitingForOpponent extends StatelessWidget {
  const _WaitingForOpponent({required this.state});

  final RaceState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          if (state.disconnected) const _ConnectionBanner(),
          const Spacer(),
          Text(
            'YOUR TIME',
            style: AppTypography.overline.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          TimeText(
            timeMs: state.yourTimeMs ?? 0,
            style: AppTypography.display,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            state.opponentReconnecting
                ? 'Your opponent dropped — waiting for them to reconnect'
                : 'Waiting for your opponent to finish',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: state.opponentReconnecting
                  ? colors.statusWarning
                  : colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OpponentProgressBar(
            opponent: state.opponent,
            yourElapsed: Duration(milliseconds: state.yourTimeMs ?? 0),
            reconnecting: state.opponentReconnecting,
          ),
          const Spacer(),
          Text(
            'The server decides the result.',
            style: AppTypography.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// --- Screens 11 & 12: Result -------------------------------------------------

class _Result extends StatelessWidget {
  const _Result({required this.state});

  final RaceState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final RaceBloc bloc = context.read<RaceBloc>();
    final RaceResult? result = state.result;

    if (result == null) return const LoadingState();

    final bool won = result.isWin;
    final Color accent = switch (result.outcome) {
      RaceOutcome.win => colors.statusSuccess,
      RaceOutcome.dnf => colors.statusWarning,
      _ => colors.statusDanger,
    };

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          const Spacer(),
          Icon(
            switch (result.outcome) {
              RaceOutcome.win => Icons.emoji_events,
              RaceOutcome.dnf => Icons.remove_circle_outline,
              _ => Icons.flag_outlined,
            },
            size: 56,
            color: accent,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            switch (result.outcome) {
              RaceOutcome.win => result.opponentLeft ? 'Win by default' : 'Win',
              RaceOutcome.dnf => 'No result',
              RaceOutcome.left => 'You left',
              RaceOutcome.loss => 'Loss',
            },
            style: AppTypography.h1.copyWith(color: accent),
          ),
          if (result.opponentLeft) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your opponent disconnected.',
              style: AppTypography.small.copyWith(color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.x3),
          _Scoreline(state: state, result: result),
          if (result.deltaMs case final int delta) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(
              won
                  ? 'You won by ${TimeText.format(delta)}'
                  : 'You lost by ${TimeText.format(delta)}',
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
          ],
          if (result.eloDelta case final int elo) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            // Server-supplied. The client never computes a rating change.
            AppChip(
              label: '${elo >= 0 ? '+' : ''}$elo Elo',
              variant: elo >= 0 ? AppChipVariant.event : AppChipVariant.dnf,
            ),
          ],
          const Spacer(),
          AppButton(
            label: 'Rematch',
            icon: Icons.refresh,
            onPressed: () => bloc.add(const RaceRematchRequested()),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.secondary(
            label: 'Back to lobby',
            onPressed: () => bloc.add(const RaceDismissed()),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

class _Scoreline extends StatelessWidget {
  const _Scoreline({required this.state, required this.result});

  final RaceState state;
  final RaceResult result;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _Side(
          label: 'You',
          timeMs: result.yourTimeMs,
          isDnf: result.yourDnf,
          highlight: result.isWin,
        ),
        Text(
          'vs',
          style: AppTypography.body.copyWith(color: colors.textMuted),
        ),
        _Side(
          label: state.opponent?.displayName ?? 'Opponent',
          timeMs: result.opponentTimeMs,
          isDnf: result.opponentDnf || result.opponentLeft,
          highlight: !result.isWin && result.outcome == RaceOutcome.loss,
        ),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.label,
    required this.timeMs,
    required this.isDnf,
    required this.highlight,
  });

  final String label;
  final int? timeMs;
  final bool isDnf;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return SizedBox(
      width: 130,
      child: Column(
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isDnf || timeMs == null)
            Text(
              'DNF',
              style: AppTypography.h2.copyWith(color: colors.statusDanger),
            )
          else
            TimeText(
              timeMs: timeMs!,
              style: AppTypography.h2,
              color: highlight ? colors.statusSuccess : colors.textPrimary,
            ),
        ],
      ),
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
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
