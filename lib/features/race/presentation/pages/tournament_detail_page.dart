import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../timer/domain/entities/wca_event.dart';
import '../../domain/entities/tournament.dart';
import '../cubit/tournaments_cubit.dart';

/// Tournament detail with its bracket — `/race/tournament/:id`.
///
/// A full-screen route (pushed above the shell). The data is demo data, so the
/// header says so; the bracket, entrant count and results are all mock.
class TournamentDetailPage extends StatelessWidget {
  const TournamentDetailPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TournamentDetailCubit>(
      create: (_) => sl<TournamentDetailCubit>()..load(id),
      child: _DetailView(id: id),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bgCanvas,
      appBar: AppBar(title: const Text('Tournament')),
      body: BlocBuilder<TournamentDetailCubit, TournamentDetailState>(
        builder: (BuildContext context, TournamentDetailState state) {
          if (state.isLoading) return const LoadingState();

          final TournamentDetail? detail = state.detail;
          if (detail == null) {
            return ErrorState(
              message: state.failure?.message,
              onRetry: () => context.read<TournamentDetailCubit>().load(id),
            );
          }

          return _Body(detail: detail);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});

  final TournamentDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Tournament t = detail.tournament;
    final WcaEvent event = WcaEvent.fromId(t.event);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        const _DemoNote(),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                t.name,
                style: AppTypography.h2.copyWith(color: colors.textPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusChip(status: t.status),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${event.name} · ${t.entrants}/${t.capacity} entered',
          style: AppTypography.small.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          t.description,
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        _RegisterButton(tournament: t),
        const SizedBox(height: AppSpacing.x3),
        Text(
          'BRACKET',
          style: AppTypography.overline.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final TournamentRound round in detail.rounds) ...<Widget>[
          Text(
            round.name,
            style: AppTypography.label.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final TournamentMatch match in round.matches)
            _MatchCard(match: match),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _DemoNote extends StatelessWidget {
  const _DemoNote();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.bgSurfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline, size: 16, color: colors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Demo data — tournaments are a preview and not yet live.',
              style: AppTypography.caption.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterButton extends StatelessWidget {
  const _RegisterButton({required this.tournament});

  final Tournament tournament;

  @override
  Widget build(BuildContext context) {
    if (tournament.status == TournamentStatus.finished) {
      return const AppButton.secondary(
        label: 'Tournament finished',
        onPressed: null,
      );
    }
    if (tournament.registered) {
      return const AppButton.secondary(
        label: "You're in ✓",
        onPressed: null,
      );
    }
    if (tournament.isFull) {
      return const AppButton.secondary(label: 'Bracket full', onPressed: null);
    }

    // The detail cubit doesn't own the list; registering here is best surfaced
    // back in the lobby, so this button just points the user there. A fuller
    // build would share one source of truth — noted for when tournaments ship.
    return AppButton(
      label: 'Register',
      onPressed: () => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Register from the Tournaments tab.')),
        ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TournamentStatus status;

  @override
  Widget build(BuildContext context) => AppChip(
        label: status.label,
        selected: status == TournamentStatus.live,
      );
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final TournamentMatch match;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          children: <Widget>[
            _Seat(
              name: match.playerA,
              timeMs: match.timeAMs,
              isWinner: match.winner == 'A',
              played: match.isPlayed,
            ),
            const SizedBox(height: AppSpacing.xs),
            _Seat(
              name: match.playerB,
              timeMs: match.timeBMs,
              isWinner: match.winner == 'B',
              played: match.isPlayed,
            ),
          ],
        ),
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({
    required this.name,
    required this.timeMs,
    required this.isWinner,
    required this.played,
  });

  final String name;
  final int? timeMs;
  final bool isWinner;
  final bool played;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool isYou = name == 'You';
    final Color nameColor = isWinner
        ? colors.brandPrimary
        : (played ? colors.textMuted : colors.textPrimary);

    return Row(
      children: <Widget>[
        if (isWinner)
          Icon(Icons.emoji_events, size: 14, color: colors.brandPrimary)
        else
          const SizedBox(width: 14),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (isYou ? AppTypography.bodyStrong : AppTypography.body)
                .copyWith(color: nameColor),
          ),
        ),
        Text(
          timeMs == null ? '—' : TimeText.format(timeMs!),
          style: AppTypography.body.copyWith(color: nameColor).tabular,
        ),
      ],
    );
  }
}
