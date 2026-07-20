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
import '../widgets/race_event_selector.dart';

/// The Race tab — `/race` (Figma `33:106`, `33:188`, `33:246`).
///
/// The lobby and the matchmaking modal over it. Everything from the **ready
/// check** onward is a separate full-screen route (`LiveRacePage`), pushed by
/// the listener below — see `RaceState.isImmersive` for why the boundary sits
/// there rather than at the countdown.
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
        // Being matched with someone is what takes you out of the shell.
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
          // No AppBar: the frame titles the screen in the body, so the header
          // can carry the Elo pill on the same baseline.
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                _Lobby(state: state),
                if (state.phase == RacePhase.searching)
                  _MatchmakingModal(state: state),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- Lobby -------------------------------------------------------------------

class _Lobby extends StatefulWidget {
  const _Lobby({required this.state});

  final RaceState state;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _LobbyHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppSegmentedControl(
                  segments: const <String>[
                    'Quick Match',
                    'Private',
                    'Tournaments',
                  ],
                  selectedIndex: _segment,
                  onChanged: (int i) => setState(() => _segment = i),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: switch (_segment) {
                    0 => const _QuickMatch(),
                    1 => _PrivateRoom(
                        state: widget.state,
                        controller: _codeController,
                      ),
                    _ => const _Tournaments(),
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// `Race`, plus an `Elo 1180 · #1,204` pill in the frame.
///
/// The pill is not rendered: Elo and global rank are server-owned and the race
/// gateway does not carry them, so there is nothing truthful to put there yet.
/// An invented number on a competitive screen is worse than no number.
class _LobbyHeader extends StatelessWidget {
  const _LobbyHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        6,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Race',
          style: AppTypography.screenTitle
              .copyWith(color: context.colors.textPrimary),
        ),
      ),
    );
  }
}

class _QuickMatch extends StatefulWidget {
  const _QuickMatch();

  @override
  State<_QuickMatch> createState() => _QuickMatchState();
}

class _QuickMatchState extends State<_QuickMatch> {
  String _event = '3x3';

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Race a random cuber',
                textAlign: TextAlign.center,
                style:
                    AppTypography.heroTitle.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 14),
              Text(
                'Same scramble. First valid solve wins.',
                textAlign: TextAlign.center,
                style:
                    AppTypography.small.copyWith(color: colors.textSecondary),
              ),
              // The frame has a best / ao5 / win-rate row here. Win rate is
              // server-owned and the other two live in the Stats feature, so
              // the row waits for a lobby endpoint rather than being stitched
              // together client-side.
              const SizedBox(height: 14),
              // Not in the frame, which predates multi-event support. Kept
              // because a race has to agree on an event before it can start,
              // and quick match can only offer the events with a population to
              // match into — see [RaceEventSelector].
              RaceEventSelector(
                selected: _event,
                quickMatchOnly: true,
                onChanged: (String id) => setState(() => _event = id),
              ),
              const SizedBox(height: 14),
              AppButton(
                label: 'Find a match',
                onPressed: () => context
                    .read<RaceBloc>()
                    .add(RaceRequested(RaceMode.quick, event: _event)),
              ),
            ],
          ),
        ),
        // `RECENT RIVALS` and its head-to-head list follow in the frame. Those
        // records are the server's, and there is no endpoint for them yet.
      ],
    );
  }
}

class _PrivateRoom extends StatefulWidget {
  const _PrivateRoom({required this.state, required this.controller});

  final RaceState state;
  final TextEditingController controller;

  @override
  State<_PrivateRoom> createState() => _PrivateRoomState();
}

class _PrivateRoomState extends State<_PrivateRoom> {
  String _event = '3x3';

  @override
  Widget build(BuildContext context) {
    final RaceBloc bloc = context.read<RaceBloc>();
    final String? code = widget.state.room?.code;

    return ListView(
      padding: EdgeInsets.zero,
      children: <Widget>[
        // Only once a room actually exists. The frame shows a code because its
        // mock has one, not because there is one before you create it.
        if (code != null) ...<Widget>[
          _RoomCodeBox(code: code),
          const SizedBox(height: AppSpacing.lg),
        ],
        // A private room takes anything raceable: you already know who is on
        // the other side, so a four-minute 7×7 is a choice the two of you can
        // make rather than a queue that will never fill.
        RaceEventSelector(
          selected: _event,
          onChanged: (String id) => setState(() => _event = id),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Create a room',
          onPressed: () =>
              bloc.add(RaceRequested(RaceMode.private, event: _event)),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              // The frame's `JOIN A ROOM` overline is this field's label. The
              // design system stacks the label above the input, so the heading
              // and the accessible name are the same string rather than a
              // heading sitting over an unlabelled box.
              child: AppTextField(
                label: 'Join a room',
                controller: widget.controller,
                hintText: 'Enter code e.g. CUBE-0000',
                textCapitalization: TextCapitalization.characters,
                maxLength: 9,
                inputFormatters: <TextInputFormatter>[
                  // Codes are uppercase alphanumerics plus the dash; typing
                  // lowercase should still work, so normalise rather than
                  // reject.
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-]')),
                ],
                onSubmitted: (String value) =>
                    bloc.add(RaceJoinRequested(value)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: 'Join',
              expand: false,
              onPressed: () =>
                  bloc.add(RaceJoinRequested(widget.controller.text)),
            ),
          ],
        ),
      ],
    );
  }
}

/// `YOUR ROOM CODE` + the code + a copy affordance (Figma `33:204`).
class _RoomCodeBox extends StatelessWidget {
  const _RoomCodeBox({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return AppCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'YOUR ROOM CODE',
                  style:
                      AppTypography.overline.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.roomCode
                      .copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppButton.secondary(
            label: 'Copy',
            expand: false,
            size: AppButtonSize.medium,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Code copied')));
            },
          ),
        ],
      ),
    );
  }
}

/// Tournaments are roadmap, not MVP (docs → Concept & Scope).
///
/// The frame's card layout is built as designed, but every card carries the
/// frame's own `SOON` badge. Its first card shows a `LIVE` tournament with
/// 1,240 entrants and an `Enter` button; rendering that against a backend with
/// no tournament endpoint would be a plain lie about a competitive feature.
class _Tournaments extends StatelessWidget {
  const _Tournaments();

  static const List<(String, String)> _planned = <(String, String)>[
    ('Global Weekly · 3×3', 'Every Sunday · open entry'),
    ('Country vs Country', 'Team brackets · seeded by nation'),
    ('Sub-15 Sprint', 'Open bracket · 64 spots'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _planned.length,
      separatorBuilder: (BuildContext _, int __) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int i) {
        final (String title, String detail) = _planned[i];
        return _TournamentCard(title: title, detail: detail);
      },
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyStrong
                      .copyWith(color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const AppChip(label: 'SOON'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            detail,
            style: AppTypography.small.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 10),
          const AppButton.secondary(
            label: 'Register',
            expand: false,
            size: AppButtonSize.medium,
            // Disabled rather than hidden: the shape of the feature is part of
            // what this screen is communicating.
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

// --- Matchmaking -------------------------------------------------------------

/// No Figma frame — the frames jump straight from the lobby to the ready room.
/// Kept as an overlay, restyled only where it would otherwise clash.
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
              style: AppTypography.roomCode.copyWith(color: colors.textPrimary),
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
