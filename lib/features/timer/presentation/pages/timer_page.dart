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
import '../bloc/timer_bloc.dart';
import '../widgets/last_solves_strip.dart';
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

/// Everything else: scramble, event, readout, penalties, session.
class _IdleBody extends StatelessWidget {
  const _IdleBody({required this.state});

  final TimerState state;

  @override
  Widget build(BuildContext context) {
    final TimerBloc bloc = context.read<TimerBloc>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              _EventChip(event: state.event),
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
            onNewScramble: () => bloc.add(const TimerScrambleRequested()),
          ),
          Expanded(child: Center(child: TimerReadout(state: state))),
          PenaltyControls(
            penalty: state.lastSolve?.penalty ?? Penalty.none,
            enabled: state.status == TimerStatus.stopped,
            onChanged: (Penalty penalty) =>
                bloc.add(TimerPenaltyChanged(penalty)),
          ),
          const SizedBox(height: AppSpacing.xl),
          LastSolvesStrip(
            solves: state.sessionSolves,
            ao5: state.sessionAo5,
            ao12: state.sessionAo12,
            onSolveTap: (solve) => context.push('/timer/solve/${solve.id}'),
            onSeeAll: () => context.push('/timer/history'),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Opens the event picker. 3×3 is the only MVP event; the sheet lists the
/// others disabled so the roadmap is visible without pretending it's built.
class _EventChip extends StatelessWidget {
  const _EventChip({required this.event});

  final String event;

  static const List<String> _comingSoon = <String>[
    '2x2',
    '4x4',
    'pyraminx',
    'megaminx',
  ];

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: _pretty(event),
      variant: AppChipVariant.event,
      icon: null,
      onTap: () => _openPicker(context),
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
            ListTile(
              leading: CubeFaceIcon.forEvent('3x3', active: true),
              title: const Text('3×3', style: AppTypography.body),
              trailing: Icon(Icons.check, color: colors.brandPrimary),
              onTap: () => Navigator.of(sheetContext).pop(),
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
