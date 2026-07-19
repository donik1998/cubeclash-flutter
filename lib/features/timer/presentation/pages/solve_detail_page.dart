import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/penalty.dart';
import '../../domain/entities/solve.dart';
import '../cubit/solve_detail_cubit.dart';
import '../widgets/penalty_controls.dart';

/// Solve Detail — `/timer/solve/:id`, a full-screen route outside the shell.
///
/// Time, penalty, the scramble it was solved on, and when. Penalty is editable
/// here as well as on the timer, because this is where you land from history
/// when you realise a solve three back should have been a DNF.
class SolveDetailPage extends StatelessWidget {
  const SolveDetailPage({super.key, required this.solveId});

  final String solveId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SolveDetailCubit>(
      create: (_) => sl<SolveDetailCubit>()..load(solveId),
      child: const _SolveDetailView(),
    );
  }
}

class _SolveDetailView extends StatelessWidget {
  const _SolveDetailView();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      appBar: AppBar(title: const Text('Solve')),
      body: BlocConsumer<SolveDetailCubit, SolveDetailState>(
        listenWhen: (SolveDetailState a, SolveDetailState b) =>
            a.deleted != b.deleted,
        listener: (BuildContext context, SolveDetailState state) {
          if (state.deleted) context.pop();
        },
        builder: (BuildContext context, SolveDetailState state) {
          if (state.isLoading) return const LoadingState();

          final Solve? solve = state.solve;
          if (solve == null) {
            return ErrorState(
              title: 'Solve not found',
              message: state.failure?.message ??
                  'It may have been deleted on another device.',
              onRetry: () =>
                  context.read<SolveDetailCubit>().load(state.solveId),
            );
          }

          return _Body(state: state, solve: solve);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.solve});

  final SolveDetailState state;
  final Solve solve;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final SolveDetailCubit cubit = context.read<SolveDetailCubit>();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Center(
          child: TimeText(
            timeMs: solve.timeMs,
            isPlus2: solve.penalty == Penalty.plus2,
            isDnf: solve.isDnf,
            style: AppTypography.display,
          ),
        ),
        if (solve.penalty != Penalty.none) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              // Show the arithmetic — a bare "14.34+" hides where it came from.
              solve.isDnf
                  ? 'Did not finish'
                  : 'Raw ${TimeText.format(solve.timeMs)} + 2.00 penalty',
              style:
                  AppTypography.caption.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.x3),
        PenaltyControls(
          penalty: solve.penalty,
          enabled: !state.isSaving,
          onChanged: cubit.changePenalty,
        ),
        const SizedBox(height: AppSpacing.x3),
        _Field(
          label: 'SCRAMBLE',
          child: Text(
            solve.scramble,
            style: AppTypography.small.copyWith(
              color: colors.textPrimary,
              letterSpacing: 0.6,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Field(
          label: 'EVENT',
          child: Row(
            children: <Widget>[
              CubeFaceIcon.forEvent(solve.event, active: true, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(solve.event, style: AppTypography.body),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _Field(
          label: 'SOLVED',
          child:
              Text(_formatTimestamp(solve.solvedAt), style: AppTypography.body),
        ),
        const SizedBox(height: AppSpacing.x4),
        AppButton.secondary(
          label: 'Delete solve',
          icon: Icons.delete_outline,
          onPressed: state.isSaving ? null : () => _confirmDelete(context),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final SolveDetailCubit cubit = context.read<SolveDetailCubit>();

    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            backgroundColor: dialogContext.colors.bgSurface,
            title: const Text('Delete this solve?'),
            content: const Text(
              'It will be removed from your history and your averages.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: dialogContext.colors.statusDanger,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) await cubit.delete();
  }

  /// `19 Jul 2026 at 14:32`. Deliberately not "3 hours ago" — a solve's
  /// timestamp is a record, and records read better absolute.
  static String _formatTimestamp(DateTime when) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final String hh = when.hour.toString().padLeft(2, '0');
    final String mm = when.minute.toString().padLeft(2, '0');
    return '${when.day} ${months[when.month - 1]} ${when.year} at $hh:$mm';
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTypography.overline.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
