import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/immersive_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/domain/entities/app_settings.dart';
import '../../../profile/presentation/cubit/settings_cubit.dart';
import '../../domain/entities/penalty.dart';
import '../../domain/entities/scramble_source.dart';
import '../../domain/entities/solve_result.dart';
import '../../domain/entities/wca_event.dart';
import '../../domain/usecases/format_result.dart';
import '../../domain/usecases/session_statistics.dart';
import '../bloc/timer_bloc.dart';
import '../widgets/event_picker_sheet.dart';
import '../widgets/manual_result_sheet.dart';
import '../widgets/penalty_controls.dart';
import '../widgets/scramble_card.dart';
import '../widgets/timer_readout.dart';

/// Timer Home — the default tab and the app's core loop.
///
/// The whole screen is the timer's touch surface. Raw pointer events go
/// straight to [TimerBloc]; this widget never decides what a press means (see
/// the bloc's doc comment). Everything except the numerals hides while a solve
/// is in flight.
class TimerPage extends StatelessWidget {
  const TimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TimerBloc>(
      create: (_) => sl<TimerBloc>()
        // Seed from the persisted settings so the very first press behaves the
        // way the user configured it, not the way the defaults do.
        ..add(TimerPreferencesChanged(
          context.read<SettingsCubit>().state.timerPreferences,
        ))
        ..add(const TimerStarted()),
      // Keep them in sync afterwards: changing timer style in Settings must
      // take effect without restarting the app.
      child: BlocListener<SettingsCubit, AppSettings>(
        listenWhen: (AppSettings a, AppSettings b) =>
            a.timerPreferences != b.timerPreferences,
        listener: (BuildContext context, AppSettings settings) => context
            .read<TimerBloc>()
            .add(TimerPreferencesChanged(settings.timerPreferences)),
        child: const _TimerView(),
      ),
    );
  }
}

class _TimerView extends StatefulWidget {
  const _TimerView();

  @override
  State<_TimerView> createState() => _TimerViewState();
}

class _TimerViewState extends State<_TimerView> {
  ImmersiveController get _immersive => sl<ImmersiveController>();

  @override
  void initState() {
    super.initState();
    // Sync on mount as well as on change: BlocConsumer's listener only fires
    // on transitions, so a view that mounts mid-flow would leave the shell
    // showing chrome it should have hidden.
    _immersive.set(context.read<TimerBloc>().state.isImmersive);
  }

  @override
  void dispose() {
    // Never strand the shell without its nav bar if this view goes away while
    // a solve is in flight.
    _immersive.set(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return BlocConsumer<TimerBloc, TimerState>(
      listenWhen: (TimerState a, TimerState b) =>
          a.isImmersive != b.isImmersive ||
          a.failure != b.failure ||
          a.status != b.status ||
          a.awaitingManualResult != b.awaitingManualResult,
      listener: _onStateChanged,
      builder: (BuildContext context, TimerState state) {
        final TimerBloc bloc = context.read<TimerBloc>();

        return Scaffold(
          backgroundColor: colors.bgCanvas,
          body: Listener(
            // Raw pointer, not GestureDetector: the gesture arena adds a
            // recognition delay, and on a speedcubing timer that delay is
            // measured against the thing being measured.
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => bloc.add(const TimerPressedDown()),
            onPointerUp: (_) => bloc.add(const TimerPressedUp()),
            onPointerCancel: (_) => bloc.add(const TimerPressedUp()),
            child: SafeArea(
              child: state.isImmersive
                  ? _ImmersiveBody(state: state)
                  : _IdleBody(state: state),
            ),
          ),
        );
      },
    );
  }

  void _onStateChanged(BuildContext context, TimerState state) {
    _immersive.set(state.isImmersive);

    // Multi-Blind stops the clock without knowing its result. Ask immediately
    // rather than leaving a finished attempt sitting unrecorded — an hour of
    // work is not something to make the user remember to file.
    if (state.awaitingManualResult) _openManualSheet(context, state);

    if (state.preferences.hapticsEnabled) {
      switch (state.status) {
        case TimerStatus.ready:
          HapticFeedback.mediumImpact();
        case TimerStatus.running:
        case TimerStatus.stopped:
          HapticFeedback.selectionClick();
        case TimerStatus.idle:
        case TimerStatus.inspecting:
          break;
      }
    }

    final String? message = state.failure?.message;
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () =>
                  context.read<TimerBloc>().add(const TimerFailureDismissed()),
            ),
          ),
        );
    }
  }

  void _openManualSheet(BuildContext context, TimerState state) {
    final TimerBloc bloc = context.read<TimerBloc>();
    ManualResultSheet.show(
      context,
      event: state.eventSpec,
      elapsedMs: state.elapsed.inMilliseconds,
      onSubmit: (ManualResult result) => bloc.add(
        TimerManualResultSubmitted(
          moveCount: result.moveCount,
          solvedCount: result.solvedCount,
          attemptedCount: result.attemptedCount,
        ),
      ),
      onCancel: () => bloc.add(const TimerManualResultCancelled()),
    );
  }
}

/// Solving: numerals and nothing else.
class _ImmersiveBody extends StatelessWidget {
  const _ImmersiveBody({required this.state});

  final TimerState state;

  @override
  Widget build(BuildContext context) =>
      Center(child: TimerReadout(state: state));
}

/// Everything else — Figma `Timer Home → content` (node `21:61`).
///
/// Column, 16pt gaps, 20pt side padding: scramble card, then a flexible timer
/// zone that centres the readout, then the three session stat cards.
///
/// The frame shows **no penalty controls in the idle state** — they appear only
/// once there is a solve to penalise, which is also the only time they mean
/// anything.
class _IdleBody extends StatelessWidget {
  const _IdleBody({required this.state});

  final TimerState state;

  @override
  Widget build(BuildContext context) {
    final TimerBloc bloc = context.read<TimerBloc>();
    final bool hasSolve = state.status == TimerStatus.stopped;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _EventChip(
                event: state.eventSpec,
                recents: state.recentEvents,
                onChanged: (String next) => bloc.add(TimerEventChanged(next)),
              ),
              const Spacer(),
              if (state.isSaving)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ScrambleCard(
            scramble: state.scramble,
            event: state.eventSpec,
            source: state.scrambleSource,
            onNewScramble: () => bloc.add(const TimerScrambleRequested()),
            onSourceChanged: (ScrambleSource source) =>
                bloc.add(TimerScrambleSourceChanged(source)),
          ),
          Expanded(child: Center(child: TimerReadout(state: state))),
          // Fewest Moves has no stopwatch, so the screen offers the one action
          // it does have instead of a touch surface that would do nothing.
          if (state.eventSpec.isManualEntry) ...<Widget>[
            AppButton(
              label: hasSolve ? 'Record another' : 'Record result',
              onPressed: () => _recordManually(context, state),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Only after a solve — see the class doc.
          if (hasSolve && !state.awaitingManualResult) ...<Widget>[
            PenaltyControls(
              penalty: state.lastSolve?.penalty ?? Penalty.none,
              enabled: true,
              showPlus2: state.lastSolve?.result.supportsPlus2 ?? true,
              onChanged: (Penalty penalty) =>
                  bloc.add(TimerPenaltyChanged(penalty)),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          _SessionStats(state: state),
        ],
      ),
    );
  }

  void _recordManually(BuildContext context, TimerState state) {
    final TimerBloc bloc = context.read<TimerBloc>();
    ManualResultSheet.show(
      context,
      event: state.eventSpec,
      elapsedMs: state.elapsed.inMilliseconds,
      onSubmit: (ManualResult result) => bloc.add(
        TimerManualResultSubmitted(
          moveCount: result.moveCount,
          solvedCount: result.solvedCount,
          attemptedCount: result.attemptedCount,
        ),
      ),
      onCancel: () {},
    );
  }
}

/// Three cards — Figma `21:76`.
///
/// **Which** three is the event's decision, not this widget's: the competition
/// format picks them (`EventFormat.sessionStats`), so a 3×3 still reads
/// `best · ao5 · ao12` exactly as the frame drew it, while a 6×6 reads
/// `best · mo3 · ao5` and Multi-Blind reads `best · last · solves`.
///
/// Value over label, left-aligned, radius 14. Tapping opens history, which the
/// frame implies by giving them card affordance rather than plain text.
class _SessionStats extends StatelessWidget {
  const _SessionStats({required this.state});

  final TimerState state;

  @override
  Widget build(BuildContext context) {
    final List<SessionStatValue> stats = state.sessionStats;

    return Row(
      children: <Widget>[
        for (int i = 0; i < stats.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _MiniStat(
              label: stats[i].stat.label,
              value: _format(stats[i]),
              onTap: () => context.push('/timer/history'),
            ),
          ),
        ],
      ],
    );
  }

  /// Formats a card by what it *is*, not by assuming milliseconds.
  static String? _format(SessionStatValue stat) {
    // A tally is a tally — zero solves is a real answer, not "not yet".
    if (stat.isCount) return '${stat.value ?? 0}';

    // `best` and `last` point at a specific attempt, so they render the whole
    // result: `11/13 in 54:22` cannot be rebuilt from one integer, and a DNF
    // should read as `DNF` rather than vanish.
    final SolveResult? result = stat.result;
    if (result != null) return FormatResult.display(result);

    final int? value = stat.value;
    if (value == null) return null;

    return switch (stat.kind) {
      // An average of move counts is rarely a whole number, and the WCA
      // records it to two decimals.
      ResultKind.moveCount => FormatResult.formatMovesMean(value.toDouble()),
      _ => FormatResult.formatTime(value),
    };
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(AppRadius.button);

    return Semantics(
      button: true,
      label: value == null ? '$label, not enough solves yet' : '$label $value',
      excludeSemantics: true,
      child: Material(
        color: colors.bgSurface,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    // `—` rather than 0.00: fewer than five solves means "not
                    // yet", not "instant".
                    value ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.miniStat
                        .copyWith(
                          color: value == null
                              ? colors.textMuted
                              : colors.textPrimary,
                        )
                        .tabular,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
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

/// Opens the event picker.
///
/// All seventeen events are selectable — see [EventPickerSheet] for how the
/// list is grouped and why nothing is disabled. The chip shows the event's
/// composed icon beside its short name, so the current event is identifiable
/// without reading.
class _EventChip extends StatelessWidget {
  const _EventChip({
    required this.event,
    required this.recents,
    required this.onChanged,
  });

  final WcaEvent event;
  final List<String> recents;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    // Figma `21:56`: label + a 10pt chevron, so the chip reads as a picker
    // rather than a static badge.
    return Semantics(
      button: true,
      label: 'Event: ${event.name}',
      excludeSemantics: true,
      child: Material(
        color: colors.brandPrimarySoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: () => EventPickerSheet.show(
            context,
            selected: event.id,
            recents: recents,
            onSelected: onChanged,
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                EventIcon(
                  event: event,
                  size: 16,
                  color: colors.brandPrimary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  event.shortName,
                  style: AppTypography.label.copyWith(
                    color: colors.brandPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 7),
                AppIcon(
                  AppIcons.chevronDown,
                  size: 10,
                  color: colors.brandPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
