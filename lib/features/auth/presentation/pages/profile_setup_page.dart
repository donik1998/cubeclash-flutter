import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/util/country_names.dart';
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

  /// The common picks, shown as one-tap chips. Anywhere else is a search away
  /// (see [_pickFromAll]), so no one is boxed out by not being on this list.
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

  Future<void> _pickFromAll() async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.bgSurface,
      builder: (BuildContext sheetContext) =>
          _CountrySearchSheet(selected: _country),
    );
    if (picked != null && mounted) setState(() => _country = picked);
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
                  // A country chosen from the full list that isn't one of the
                  // common picks still shows here, selected.
                  if (_country != null &&
                      !_countries.any(((String, String) c) => c.$1 == _country))
                    AppChip(
                      label:
                          '${countryCodeToFlag(_country!)} ${countryCodeToName(_country!) ?? _country!}',
                      selected: true,
                      onTap: () => setState(() => _country = null),
                    ),
                  AppChip(
                    label: '🔎 Search all countries',
                    selected: false,
                    onTap: _pickFromAll,
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

/// A searchable list of every country, opened from the setup screen when the
/// common chips don't cover you. Filters `kCountryNames` as you type and pops
/// the chosen ISO code.
class _CountrySearchSheet extends StatefulWidget {
  const _CountrySearchSheet({required this.selected});

  final String? selected;

  @override
  State<_CountrySearchSheet> createState() => _CountrySearchSheetState();
}

class _CountrySearchSheetState extends State<_CountrySearchSheet> {
  final TextEditingController _query = TextEditingController();

  /// The full list, once, sorted by name — filtered per keystroke.
  static final List<MapEntry<String, String>> _all = kCountryNames.entries
      .toList()
    ..sort((MapEntry<String, String> a, MapEntry<String, String> b) =>
        a.value.compareTo(b.value));

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final String q = _query.text.trim().toLowerCase();
    final List<MapEntry<String, String>> matches = q.isEmpty
        ? _all
        : _all
            .where((MapEntry<String, String> e) =>
                e.value.toLowerCase().contains(q) || e.key.toLowerCase() == q)
            .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppTextField(
                label: 'Country',
                controller: _query,
                hintText: 'Search countries',
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? const EmptyState(
                      title: 'No match',
                      message: 'Try a different spelling.',
                      icon: Icons.public_off,
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (BuildContext context, int i) {
                        final MapEntry<String, String> c = matches[i];
                        final bool selected = c.key == widget.selected;
                        return ListTile(
                          leading: Text(
                            countryCodeToFlag(c.key) ?? '🏳️',
                            style: AppTypography.h2,
                          ),
                          title: Text(
                            c.value,
                            style: AppTypography.body
                                .copyWith(color: colors.textPrimary),
                          ),
                          trailing: selected
                              ? Icon(Icons.check, color: colors.brandPrimary)
                              : null,
                          onTap: () => Navigator.of(context).pop(c.key),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
