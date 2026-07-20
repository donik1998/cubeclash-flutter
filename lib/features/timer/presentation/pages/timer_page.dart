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
import '../bloc/timer_bloc.dart';
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
          a.status != b.status,
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
                event: state.event,
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
            source: state.scrambleSource,
            onNewScramble: () => bloc.add(const TimerScrambleRequested()),
            onSourceChanged: (ScrambleSource source) =>
                bloc.add(TimerScrambleSourceChanged(source)),
          ),
          Expanded(child: Center(child: TimerReadout(state: state))),
          // Only after a solve — see the class doc.
          if (hasSolve) ...<Widget>[
            PenaltyControls(
              penalty: state.lastSolve?.penalty ?? Penalty.none,
              enabled: true,
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
}

/// Three cards: best · ao5 · ao12 — Figma `21:76`.
///
/// Value over label, left-aligned, radius 14. Tapping opens history, which the
/// frame implies by giving them card affordance rather than plain text.
class _SessionStats extends StatelessWidget {
  const _SessionStats({required this.state});

  final TimerState state;

  @override
  Widget build(BuildContext context) {
    String? fmt(int? ms) => ms == null ? null : TimeText.format(ms);

    return Row(
      children: <Widget>[
        Expanded(
          child: _MiniStat(
            label: 'best',
            value: fmt(state.sessionBest),
            onTap: () => context.push('/timer/history'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MiniStat(
            label: 'ao5',
            value: fmt(state.sessionAo5),
            onTap: () => context.push('/timer/history'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MiniStat(
            label: 'ao12',
            value: fmt(state.sessionAo12),
            onTap: () => context.push('/timer/history'),
          ),
        ),
      ],
    );
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

/// Opens the event picker. 3×3 is the only MVP event; the sheet lists the
/// others disabled so the roadmap is visible without pretending it's built.
class _EventChip extends StatelessWidget {
  const _EventChip({required this.event, required this.onChanged});

  final String event;
  final ValueChanged<String> onChanged;

  /// Events the scrambler can actually produce (see `PuzzleSpec.byEvent`).
  static const List<String> _available = <String>['3x3', '4x4'];

  static const List<String> _comingSoon = <String>[
    '2x2',
    'pyraminx',
    'megaminx',
  ];

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    // Figma `21:56`: label + a 10pt chevron, so the chip reads as a picker
    // rather than a static badge.
    return Semantics(
      button: true,
      label: 'Event: ${_pretty(event)}',
      excludeSemantics: true,
      child: Material(
        color: colors.brandPrimarySoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _pretty(event),
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

  static String _pretty(String event) => switch (event) {
        '2x2' => '2×2',
        '3x3' => '3×3',
        '4x4' => '4×4',
        _ => event,
      };

  void _openPicker(BuildContext context) {
    final AppColors colors = context.colors;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Event',
                style: AppTypography.title.copyWith(color: colors.textPrimary),
              ),
            ),
            for (final String available in _available)
              ListTile(
                leading: CubeFaceIcon.forEvent(
                  available,
                  active: available == event,
                ),
                title: Text(_pretty(available), style: AppTypography.body),
                trailing: available == event
                    ? Icon(Icons.check, color: colors.brandPrimary)
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onChanged(available);
                },
              ),
            for (final String other in _comingSoon)
              ListTile(
                enabled: false,
                leading: CubeFaceIcon.forEvent(other),
                title: Text(
                  _pretty(other),
                  style: AppTypography.body.copyWith(color: colors.textMuted),
                ),
                trailing: Text(
                  'Soon',
                  style:
                      AppTypography.caption.copyWith(color: colors.textMuted),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
