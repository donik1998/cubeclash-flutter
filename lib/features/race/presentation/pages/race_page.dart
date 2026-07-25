import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/realtime/race_gateway.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../timer/domain/entities/wca_event.dart';
import '../../domain/entities/lobby_summary.dart';
import '../../domain/entities/race_room.dart';
import '../../domain/entities/tournament.dart';
import '../bloc/race_bloc.dart';
import '../cubit/lobby_cubit.dart';
import '../cubit/tournaments_cubit.dart';
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
    // Race and Result screens are separate routes. The LobbyCubit is per-screen
    // — its Elo / stats / rivals summary is only needed while the lobby is up.
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<RaceBloc>.value(
            value: sl<RaceBloc>()..add(const RaceOpened())),
        BlocProvider<LobbyCubit>(create: (_) => sl<LobbyCubit>()..load()),
      ],
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
        if (widget.state.connection != GatewayConnection.connected)
          _ConnectionBanner(connection: widget.state.connection),
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

/// `Race`, plus the frame's `Elo 1180 · #1,204` pill — now real, fed by the
/// server-owned [LobbySummary] rather than invented client-side.
class _LobbyHeader extends StatelessWidget {
  const _LobbyHeader();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        6,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Race',
              style:
                  AppTypography.screenTitle.copyWith(color: colors.textPrimary),
            ),
          ),
          BlocBuilder<LobbyCubit, LobbyState>(
            builder: (BuildContext context, LobbyState state) {
              final LobbySummary? s = state.summary;
              if (s == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.brandPrimarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'Elo ${s.elo} · #${_grouped(s.globalRank)}',
                  style: AppTypography.small
                      .copyWith(color: colors.brandPrimary)
                      .tabular,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// `1204` → `1,204`.
  static String _grouped(int n) {
    final String s = n.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }
}

/// A thin banner while the race socket is connecting or dropped, so the lobby
/// shows its network state rather than looking idle. Non-blocking — you can
/// still queue; the bloc handles the connection underneath.
class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.connection});

  final GatewayConnection connection;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool connecting = connection == GatewayConnection.connecting;
    final String label =
        connecting ? 'Connecting…' : 'Reconnecting to the race server…';

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
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
          SizedBox(
            width: 14,
            height: 14,
            // A spinner is an infinite animation; under reduce-motion (and so in
            // widget tests, which pump-and-settle) fall back to a static dot.
            child: MediaQuery.disableAnimationsOf(context)
                ? Icon(Icons.circle, size: 10, color: colors.textMuted)
                : CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textMuted,
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: colors.textSecondary),
          ),
        ],
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
              // The frame's best / ao5 / win-rate row — from the lobby summary
              // endpoint, so nothing is stitched together on the client.
              const SizedBox(height: 14),
              BlocBuilder<LobbyCubit, LobbyState>(
                builder: (BuildContext context, LobbyState state) {
                  final LobbySummary? s = state.summary;
                  if (s == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        _LobbyStat(
                          label: 'Best',
                          value: s.bestSingleMs == null
                              ? '—'
                              : TimeText.format(s.bestSingleMs!),
                        ),
                        _LobbyStat(
                          label: 'Ao5',
                          value:
                              s.ao5Ms == null ? '—' : TimeText.format(s.ao5Ms!),
                        ),
                        _LobbyStat(
                          label: 'Win rate',
                          value: s.winRate == null ? '—' : '${s.winRate}%',
                        ),
                      ],
                    ),
                  );
                },
              ),
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
        // `RECENT RIVALS` — head-to-head records from the lobby summary.
        BlocBuilder<LobbyCubit, LobbyState>(
          builder: (BuildContext context, LobbyState state) {
            final List<Rival> rivals = state.summary?.recentRivals ?? <Rival>[];
            if (rivals.isEmpty) return const SizedBox.shrink();
            return _RecentRivals(rivals: rivals);
          },
        ),
      ],
    );
  }
}

class _LobbyStat extends StatelessWidget {
  const _LobbyStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Column(
      children: <Widget>[
        Text(
          value,
          style:
              AppTypography.title.copyWith(color: colors.textPrimary).tabular,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.overline.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

class _RecentRivals extends StatelessWidget {
  const _RecentRivals({required this.rivals});

  final List<Rival> rivals;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: AppSpacing.xl),
        Text(
          'RECENT RIVALS',
          style: AppTypography.overline.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final Rival r in rivals)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              onTap: () => context.push('/stats/player/${r.userId}'),
              child: Row(
                children: <Widget>[
                  if (countryCodeToFlag(r.countryCode)
                      case final String flag) ...<Widget>[
                    Text(flag, style: AppTypography.body),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      r.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body
                          .copyWith(color: colors.textPrimary),
                    ),
                  ),
                  Text(
                    '${r.wins}–${r.losses}',
                    style: AppTypography.bodyStrong
                        .copyWith(
                          color: r.wins >= r.losses
                              ? colors.statusSuccess
                              : colors.textMuted,
                        )
                        .tabular,
                  ),
                ],
              ),
            ),
          ),
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

/// The Tournaments tab — a real, mock-backed feature.
///
/// The data is demo data (the header note says so, and the detail screen
/// repeats it), because tournaments are server-owned and no backend runs them
/// yet. But the flow is real: a live bracket you can open, upcoming events you
/// can register for, a finished one you can review.
class _Tournaments extends StatelessWidget {
  const _Tournaments();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TournamentsCubit>(
      create: (_) => sl<TournamentsCubit>()..load(),
      child: const _TournamentsList(),
    );
  }
}

class _TournamentsList extends StatelessWidget {
  const _TournamentsList();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TournamentsCubit, TournamentsState>(
      listenWhen: (TournamentsState a, TournamentsState b) =>
          a.failure != b.failure,
      listener: (BuildContext context, TournamentsState state) {
        final String? message = state.failure?.message;
        if (message != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (BuildContext context, TournamentsState state) {
        final TournamentsCubit cubit = context.read<TournamentsCubit>();

        if (state.isLoading) return const LoadingState();
        if (state.failure != null && state.tournaments.isEmpty) {
          return ErrorState(
            message: state.failure!.message,
            onRetry: cubit.load,
          );
        }
        if (state.isEmpty) {
          return const EmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'No tournaments',
            message: 'Check back soon — new brackets open every week.',
          );
        }

        return RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: <Widget>[
              const _DemoBanner(),
              const SizedBox(height: AppSpacing.md),
              for (final Tournament t in state.tournaments) ...<Widget>[
                _TournamentCard(
                  tournament: t,
                  isRegistering: state.registeringId == t.id,
                  onRegister: () => cubit.register(t.id),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

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
              'Demo data — a preview of tournaments, not yet live.',
              style: AppTypography.caption.copyWith(color: colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({
    required this.tournament,
    required this.isRegistering,
    required this.onRegister,
  });

  final Tournament tournament;
  final bool isRegistering;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Tournament t = tournament;
    final WcaEvent event = WcaEvent.fromId(t.event);

    return AppCard(
      onTap: () => context.push('/race/tournament/${t.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  t.name,
                  style: AppTypography.bodyStrong
                      .copyWith(color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppChip(
                label: t.status.label,
                selected: t.status == TournamentStatus.live,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${event.name} · ${t.entrants}/${t.capacity} entered',
            style: AppTypography.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 10),
          Text(
            t.description,
            style: AppTypography.small.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 12),
          _CardAction(
            tournament: t,
            isRegistering: isRegistering,
            onRegister: onRegister,
          ),
        ],
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.tournament,
    required this.isRegistering,
    required this.onRegister,
  });

  final Tournament tournament;
  final bool isRegistering;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final Tournament t = tournament;

    if (t.status == TournamentStatus.live) {
      return AppButton.secondary(
        label: 'View bracket',
        expand: false,
        size: AppButtonSize.medium,
        onPressed: () => context.push('/race/tournament/${t.id}'),
      );
    }
    if (t.status == TournamentStatus.finished) {
      return AppButton.secondary(
        label: 'See results',
        expand: false,
        size: AppButtonSize.medium,
        onPressed: () => context.push('/race/tournament/${t.id}'),
      );
    }
    if (t.registered) {
      return const AppButton.secondary(
        label: "You're in ✓",
        expand: false,
        size: AppButtonSize.medium,
        onPressed: null,
      );
    }
    return AppButton(
      label: t.isFull ? 'Full' : 'Register',
      expand: false,
      size: AppButtonSize.medium,
      isLoading: isRegistering,
      onPressed: t.isFull ? null : onRegister,
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
  // Initialised in initState, not lazily: under reduce-motion `build` never
  // touches it, and a `late final` first-touched in `dispose` would construct a
  // Ticker (an ancestor lookup) on a deactivated element and throw.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

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
