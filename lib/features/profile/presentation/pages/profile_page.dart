import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/profile_summary_cubit.dart';
import '../widgets/profile_content.dart';

/// You · Profile — `/you` (Figma `47:158` dark / `47:375` light).
///
/// Layer A: the only layer that knows about state. It provides the
/// [ProfileSummaryCubit], subscribes, and hands plain values and callbacks down
/// to the pure [ProfileContent]. No layout math, no styling, no formatting.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileSummaryCubit>(
      create: (_) => sl<ProfileSummaryCubit>()..load(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  /// Copies a plain profile link to the clipboard and confirms with a snackbar.
  ///
  /// Client-side only (spec §11.5): there is no `share_plus` dependency and no
  /// server support for sharing yet, so this stands in for the native share
  /// sheet by putting a plain URL on the clipboard.
  Future<void> _share(BuildContext context, String userId) async {
    await Clipboard.setData(
      ClipboardData(text: 'https://cubeclash.app/u/$userId'),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Profile link copied')));
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      body: BlocBuilder<ProfileSummaryCubit, ProfileSummaryState>(
        builder: (BuildContext context, ProfileSummaryState state) {
          return ProfileContent(
            summary: state.summary,
            isLoading: state.isLoading,
            hasError: state.failure != null && state.summary == null,
            errorMessage: state.failure?.message,
            onRetry: context.read<ProfileSummaryCubit>().retry,
            onFriends: () => context.push('/you/friends'),
            onShare: () => _share(context, state.summary?.id ?? 'me'),
            onSettings: () => context.push('/you/settings'),
          );
        },
      ),
    );
  }
}
