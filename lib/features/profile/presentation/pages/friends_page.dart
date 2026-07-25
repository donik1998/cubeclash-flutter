import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/user_profile.dart';
import '../cubit/friends_cubit.dart';

/// Friends — `/you/friends`.
///
/// Three groups, in the order they need attention: requests waiting on you,
/// then your friends, then invitations you're waiting on.
class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FriendsCubit>(
      create: (_) => sl<FriendsCubit>()..load(),
      child: const _FriendsView(),
    );
  }
}

class _FriendsView extends StatefulWidget {
  const _FriendsView();

  @override
  State<_FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<_FriendsView> {
  final TextEditingController _inviteController = TextEditingController();

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      appBar: AppBar(title: const Text('Friends')),
      body: BlocConsumer<FriendsCubit, FriendsState>(
        listenWhen: (FriendsState a, FriendsState b) =>
            a.inviteSent != b.inviteSent || a.failure != b.failure,
        listener: (BuildContext context, FriendsState state) {
          if (state.inviteSent) {
            _inviteController.clear();
            context.read<FriendsCubit>().acknowledgeInvite();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Invite sent')));
          }
          final String? message = state.failure?.message;
          if (message != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          }
        },
        builder: (BuildContext context, FriendsState state) {
          final FriendsCubit cubit = context.read<FriendsCubit>();

          if (state.isLoading) return const LoadingState();

          if (state.failure != null && state.friends.isEmpty) {
            return ErrorState(
              message: state.failure!.message,
              onRetry: cubit.load,
            );
          }

          // Pull-to-refresh so a reload that failed on cached data (surfaced as
          // a snackbar) has a way to be retried without leaving the screen.
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                _InviteCard(
                  controller: _inviteController,
                  isSubmitting: state.isSubmitting,
                  onInvite: cubit.invite,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (state.isEmpty)
                  const EmptyState(
                    icon: Icons.people_outline,
                    title: 'No friends yet',
                    message:
                        'Invite someone above and their times show up on your '
                        'friends leaderboard.',
                  )
                else ...<Widget>[
                  if (state.incomingRequests.isNotEmpty) ...<Widget>[
                    _Header('REQUESTS · ${state.incomingRequests.length}'),
                    for (final Friend friend in state.incomingRequests)
                      _FriendRow(
                        friend: friend,
                        onAccept: state.isSubmitting
                            ? null
                            : () => cubit.accept(friend.userId),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  if (state.accepted.isNotEmpty) ...<Widget>[
                    const _Header('FRIENDS'),
                    for (final Friend friend in state.accepted)
                      _FriendRow(friend: friend),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  if (state.outgoingRequests.isNotEmpty) ...<Widget>[
                    const _Header('INVITED'),
                    for (final Friend friend in state.outgoingRequests)
                      _FriendRow(friend: friend),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.controller,
    required this.isSubmitting,
    required this.onInvite,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final ValueChanged<String> onInvite;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppTextField(
            label: 'Add a friend',
            controller: controller,
            hintText: 'Name or email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            onSubmitted: onInvite,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Send invite',
            isLoading: isSubmitting,
            onPressed: () => onInvite(controller.text),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          label,
          style:
              AppTypography.overline.copyWith(color: context.colors.textMuted),
        ),
      );
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, this.onAccept});

  final Friend friend;

  /// Only incoming requests get an Accept button — you can't accept your own
  /// invitation.
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final String? flag = countryCodeToFlag(friend.countryCode);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        onTap: () => context.push('/stats/player/${friend.userId}'),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.bgSurfaceAlt,
              ),
              alignment: Alignment.center,
              child: Text(
                friend.displayName.isEmpty
                    ? '?'
                    : friend.displayName.characters.first.toUpperCase(),
                style:
                    AppTypography.label.copyWith(color: colors.textSecondary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          friend.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body
                              .copyWith(color: colors.textPrimary),
                        ),
                      ),
                      if (flag != null) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        Text(flag, style: AppTypography.small),
                      ],
                    ],
                  ),
                  if (friend.bestSingleMs != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'PB ${TimeText.format(friend.bestSingleMs!)}',
                      style: AppTypography.caption
                          .copyWith(color: colors.textMuted)
                          .tabular,
                    ),
                  ],
                ],
              ),
            ),
            if (onAccept != null)
              AppButton(
                label: 'Accept',
                size: AppButtonSize.medium,
                expand: false,
                onPressed: onAccept,
              )
            else if (friend.status == FriendStatus.pending)
              const AppChip(label: 'Pending'),
          ],
        ),
      ),
    );
  }
}
