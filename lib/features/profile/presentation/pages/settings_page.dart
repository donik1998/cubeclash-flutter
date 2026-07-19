import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../timer/domain/entities/timer_preferences.dart';
import '../../domain/entities/app_settings.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/settings_cubit.dart';

/// Settings — `/you/settings`.
///
/// Every control writes through immediately; there is no save button, so
/// nothing can be lost by backing out.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return BlocProvider<ProfileCubit>(
      create: (_) => sl<ProfileCubit>()..load(),
      child: Scaffold(
        backgroundColor: colors.bgCanvas,
        appBar: AppBar(title: const Text('Settings')),
        // SettingsCubit is provided app-wide (see app.dart) — the theme is one
        // of its values, so it has to live above MaterialApp.
        body: BlocBuilder<SettingsCubit, AppSettings>(
          builder: (BuildContext context, AppSettings settings) {
            final SettingsCubit cubit = context.read<SettingsCubit>();

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                const _SectionHeader('APPEARANCE'),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppSegmentedControl(
                    segments: AppThemeMode.values
                        .map((AppThemeMode m) => m.label)
                        .toList(),
                    selectedIndex: settings.themeMode.index,
                    onChanged: (int i) =>
                        cubit.setThemeMode(AppThemeMode.values[i]),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionHeader('TIMER'),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: <Widget>[
                      AppSegmentedControl(
                        segments: const <String>[
                          'Hold to start',
                          'Tap to start'
                        ],
                        selectedIndex: settings.timerStyle.index,
                        onChanged: (int i) =>
                            cubit.setTimerStyle(TimerStyle.values[i]),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SettingSwitch(
                        label: 'WCA inspection',
                        description:
                            '15 seconds before each solve. Over 15s is +2, '
                            'over 17s is a DNF.',
                        value: settings.inspectionEnabled,
                        onChanged: cubit.setInspectionEnabled,
                      ),
                      _SettingSwitch(
                        label: 'Haptics',
                        description: 'Vibrate when the timer arms and stops.',
                        value: settings.hapticsEnabled,
                        onChanged: cubit.setHapticsEnabled,
                      ),
                      _SettingSwitch(
                        label: 'Sound',
                        description: 'Inspection cues at 8 and 12 seconds.',
                        value: settings.soundEnabled,
                        onChanged: cubit.setSoundEnabled,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _SectionHeader('ACCOUNT'),
                const _AccountCard(),
                const SizedBox(height: AppSpacing.xl),
                const _SignOutButton(),
                const SizedBox(height: AppSpacing.xl),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

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

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: colors.brandPrimary,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: AppTypography.body.copyWith(color: colors.textPrimary),
      ),
      subtitle: Text(
        description,
        style: AppTypography.caption.copyWith(color: colors.textMuted),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (BuildContext context, ProfileState state) {
        if (state.isLoading) {
          return const AppCard(
            child: SizedBox(height: 56, child: LoadingState()),
          );
        }

        final String name = state.profile?.displayName ?? '—';
        final String email = state.profile?.email ?? 'Not signed in';

        return AppCard(
          onTap: () => _editName(context, name),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: AppTypography.bodyStrong
                          .copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      email,
                      style: AppTypography.caption
                          .copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textMuted),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editName(BuildContext context, String current) async {
    final ProfileCubit cubit = context.read<ProfileCubit>();
    final TextEditingController controller =
        TextEditingController(text: current);

    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: dialogContext.colors.bgSurface,
        title: const Text('Display name'),
        content: AppTextField(
          label: 'Name',
          controller: controller,
          autofocus: true,
          maxLength: 24,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (name != null && name.isNotEmpty && name != current) {
      await cubit.updateProfile(displayName: name);
    }
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listenWhen: (ProfileState a, ProfileState b) =>
          a.signedOut != b.signedOut,
      listener: (BuildContext context, ProfileState state) {
        // The router's auth guard takes it from here (Phase F).
        if (state.signedOut) context.go('/auth');
      },
      builder: (BuildContext context, ProfileState state) =>
          AppButton.secondary(
        label: 'Sign out',
        isLoading: state.isSaving,
        onPressed: () => _confirm(context),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final ProfileCubit cubit = context.read<ProfileCubit>();

    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            backgroundColor: dialogContext.colors.bgSurface,
            title: const Text('Sign out?'),
            content: const Text(
              'Your solves stay on this device and sync when you sign back in.',
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
                child: const Text('Sign out'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) await cubit.logout();
  }
}
