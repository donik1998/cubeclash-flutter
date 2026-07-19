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

/// The Race tab — `/race`.
///
/// Three screens in one route, chosen by phase: the lobby, the matchmaking
/// modal over it, and the ready room. The live race is a separate full-screen
/// route (see [AppRouter]), pushed by the listener below when the countdown
/// starts.
class RacePage extends StatelessWidget {
  const RacePage({super.key});

  @override
  Widget build(BuildContext context) {
    // The RaceBloc is a singleton: a race outlives this widget, since the Live
    // Race and Result screens are separate routes.
    return BlocProvider<RaceBloc>.value(
      value: sl<RaceBloc>()..add(const RaceOpened()),
      child: const _RaceView(),
    );
  }
}

class _RaceView extends StatelessWidget {
  const _RaceView();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return BlocConsumer<RaceBloc, RaceState>(
      listenWhen: (RaceState a, RaceState b) =>
          a.isImmersive != b.isImmersive || a.failure != b.failure,
      listener: (BuildContext context, RaceState state) {
        // The countdown starting is what takes you out of the shell.
        if (state.isImmersive) context.push('/race/live');

        final String? message = state.failure?.message;
        if (message != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (BuildContext context, RaceState state) {
        return Scaffold(
          backgroundColor: colors.bgCanvas,
          appBar: AppBar(title: const Text('Race')),
          body: Stack(
            children: <Widget>[
              switch (state.phase) {
                RacePhase.readyCheck => _ReadyRoom(state: state),
                _ => const _Lobby(),
              },
              if (state.phase == RacePhase.searching)
                _MatchmakingModal(state: state),
            ],
          ),
        );
      },
    );
  }
}

// --- Screen 7: Race Lobby ----------------------------------------------------

class _Lobby extends StatefulWidget {
  const _Lobby();

  @override
  State<_Lobby> createState() => _LobbyState();
}

class _LobbyState extends State<_Lobby> {
  int _segment = 0;
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          AppSegmentedControl(
            segments: const <String>['Quick Match', 'Private', 'Tournaments'],
            selectedIndex: _segment,
            onChanged: (int i) => setState(() => _segment = i),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: switch (_segment) {
              0 => const _QuickMatch(),
              1 => _PrivateRoom(controller: _codeController),
              _ => const _Tournaments(),
            },
          ),
        ],
      ),
    );
  }
}

class _QuickMatch extends StatelessWidget {
  const _QuickMatch();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.bolt, size: 56, color: colors.brandPrimary),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Race someone now',
          style: AppTypography.h2.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Same scramble, same moment. First to solve wins.',
          textAlign: TextAlign.center,
          style: AppTypography.small.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.x3),
        AppButton(
          label: 'Find a match',
          icon: Icons.search,
          onPressed: () =>
              context.read<RaceBloc>().add(const RaceRequested(RaceMode.quick)),
        ),
      ],
    );
  }
}

class _PrivateRoom extends StatelessWidget {
  const _PrivateRoom({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final RaceBloc bloc = context.read<RaceBloc>();

    return ListView(
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Create a room',
                style: AppTypography.title.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You get a code to share. They join, you both ready up.',
                style:
                    AppTypography.small.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Create room',
                onPressed: () =>
                    bloc.add(const RaceRequested(RaceMode.private)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Join with a code',
                style: AppTypography.title.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Invite code',
                controller: controller,
                hintText: 'ABC123',
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                inputFormatters: <TextInputFormatter>[
                  // Codes are uppercase alphanumerics; typing lowercase should
                  // still work, so normalise rather than reject.
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                ],
                onSubmitted: (String code) => bloc.add(RaceJoinRequested(code)),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton.secondary(
                label: 'Join room',
                onPressed: () => bloc.add(RaceJoinRequested(controller.text)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tournaments are roadmap, not MVP (docs → Concept & Scope). The layout is
/// real so the shape is designed; the content says so plainly rather than
/// pretending.
class _Tournaments extends StatelessWidget {
  const _Tournaments();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Column(
      children: <Widget>[
        for (int i = 0; i < 2; i++) ...<Widget>[
          Opacity(
            opacity: 0.55,
            child: AppCard(
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.bgSurfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.emoji_events_outlined,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          i == 0 ? 'Weekly 3×3 Open' : 'Country Cup',
                          style: AppTypography.bodyStrong
                              .copyWith(color: colors.textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          i == 0 ? 'Sundays · 32 players' : 'Monthly · Swiss',
                          style: AppTypography.caption
                              .copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const AppChip(label: 'Soon'),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Tournaments are on the roadmap — brackets, Swiss rounds and '
            'country-vs-country leagues.',
            textAlign: TextAlign.center,
            style: AppTypography.small.copyWith(color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}

// --- Screen 8: Matchmaking ---------------------------------------------------

class _MatchmakingModal extends StatelessWidget {
  const _MatchmakingModal({required this.state});

  final RaceState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final String? code = state.room?.code;

    return Positioned.fill(
      child: ColoredBox(
        color: colors.bgCanvas.withValues(alpha: 0.92),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const _SearchingPulse(),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  state.mode == RaceMode.private
                      ? 'Waiting for your opponent'
                      : 'Finding an opponent',
                  style:
                      AppTypography.title.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _waitLabel(state.searchElapsed),
                  style: AppTypography.body
                      .copyWith(color: colors.textSecondary)
                      .tabular,
                ),
                if (code != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'INVITE CODE',
                    style: AppTypography.overline
                        .copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InviteCode(code: code),
                ],
                const SizedBox(height: AppSpacing.x3),
                AppButton.secondary(
                  label: 'Cancel',
                  expand: false,
                  onPressed: () =>
                      context.read<RaceBloc>().add(const RaceCancelled()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _waitLabel(Duration elapsed) {
    final int s = elapsed.inSeconds;
    if (s < 60) return '${s}s';
    return '${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s';
  }
}

class _InviteCode extends StatelessWidget {
  const _InviteCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Code copied')));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.bgSurfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              code,
              style: AppTypography.h2
                  .copyWith(color: colors.textPrimary, letterSpacing: 4)
                  .tabular,
            ),
            const SizedBox(width: AppSpacing.md),
            Icon(Icons.copy, size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// A slow pulse while searching. Falls back to a static ring under
/// reduce-motion.
class _SearchingPulse extends StatefulWidget {
  const _SearchingPulse();

  @override
  State<_SearchingPulse> createState() => _SearchingPulseState();
}

class _SearchingPulseState extends State<_SearchingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    final Widget ring = Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.brandPrimarySoft,
      ),
      child: Icon(Icons.bolt, size: 36, color: colors.brandPrimary),
    );

    if (reduceMotion) return ring;

    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1.06).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: ring,
    );
  }
}

// --- Screen 9: Ready Room ----------------------------------------------------

class _ReadyRoom extends StatelessWidget {
  const _ReadyRoom({required this.state});

  final RaceState state;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final RaceBloc bloc = context.read<RaceBloc>();
    final bool youReady = state.you?.ready ?? false;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          Text(
            'Ready up',
            style: AppTypography.h2.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The race starts when you both confirm.',
            textAlign: TextAlign.center,
            style: AppTypography.small.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.x3),
          RacePlayerCard(player: state.you),
          const SizedBox(height: AppSpacing.md),
          RacePlayerCard(player: state.opponent),
          const Spacer(),
          AppButton(
            label: youReady ? "Waiting for them…" : "I'm ready",
            onPressed:
                youReady ? null : () => bloc.add(const RaceReadyPressed()),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.ghost(
            label: 'Leave',
            expand: true,
            onPressed: () => bloc.add(const RaceCancelled()),
          ),
        ],
      ),
    );
  }
}
