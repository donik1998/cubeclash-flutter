import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/auth_cubit.dart';

/// Profile setup — `/auth/setup`. The last step of registration.
///
/// Country is asked for once, here, because it drives the country leaderboard
/// and the flag beside your name. Asking later means nagging; not asking means
/// a whole leaderboard scope nobody can use.
class ProfileSetupPage extends StatelessWidget {
  const ProfileSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>(
      create: (_) => sl<AuthCubit>(),
      child: const _ProfileSetupView(),
    );
  }
}

class _ProfileSetupView extends StatefulWidget {
  const _ProfileSetupView();

  @override
  State<_ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<_ProfileSetupView> {
  final TextEditingController _displayName = TextEditingController();
  String? _nameError;
  String? _country;

  /// A short list rather than all 249 codes: a picker with a search field is a
  /// screen of its own, and this is a one-tap step. "Somewhere else" keeps the
  /// door open without blocking anyone.
  static const List<(String, String)> _countries = <(String, String)>[
    ('GB', 'United Kingdom'),
    ('US', 'United States'),
    ('DE', 'Germany'),
    ('FR', 'France'),
    ('BR', 'Brazil'),
    ('JP', 'Japan'),
    ('CN', 'China'),
    ('IN', 'India'),
    ('UZ', 'Uzbekistan'),
    ('AU', 'Australia'),
  ];

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  void _submit() {
    final String? error = AuthValidators.displayName(_displayName.text);
    setState(() => _nameError = error);
    if (error != null) return;

    context.read<AuthCubit>().completeProfile(
          displayName: _displayName.text,
          country: _country,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      appBar: AppBar(
        title: const Text('Set up your profile'),
        automaticallyImplyLeading: false,
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listenWhen: (AuthState a, AuthState b) =>
            a.succeeded != b.succeeded || a.failure != b.failure,
        listener: (BuildContext context, AuthState state) {
          if (state.succeeded) context.go('/timer');

          final String? message = state.failure?.message;
          if (message != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          }
        },
        builder: (BuildContext context, AuthState state) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: <Widget>[
              Text(
                'Almost there',
                style: AppTypography.h2.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This is what other cubers see on leaderboards and in races.',
                style:
                    AppTypography.small.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.x3),
              AppTextField(
                label: 'Display name',
                controller: _displayName,
                hintText: 'cuber99',
                errorText: _nameError,
                autofocus: true,
                maxLength: 24,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'COUNTRY',
                style: AppTypography.overline.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Optional — it puts you on the country leaderboard.',
                style: AppTypography.caption.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final (String code, String name) in _countries)
                    AppChip(
                      label: '${countryCodeToFlag(code)} $name',
                      selected: _country == code,
                      onTap: () => setState(
                        // Tapping the selected country clears it — the field
                        // is optional, so it has to be un-settable.
                        () => _country = _country == code ? null : code,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.x4),
              AppButton(
                label: 'Start solving',
                isLoading: state.isSubmitting,
                onPressed: _submit,
              ),
            ],
          );
        },
      ),
    );
  }
}
