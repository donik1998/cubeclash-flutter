import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../cubit/auth_cubit.dart';

/// Log in (`/auth/login`) and Sign up (`/auth/register`).
///
/// One widget for both: the fields differ by exactly one row, and two
/// near-identical screens drift apart the moment either is touched.
class SignInPage extends StatelessWidget {
  const SignInPage({super.key, required this.isRegister});

  final bool isRegister;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthCubit>(
      create: (_) => sl<AuthCubit>(),
      child: _SignInView(isRegister: isRegister),
    );
  }
}

class _SignInView extends StatefulWidget {
  const _SignInView({required this.isRegister});

  final bool isRegister;

  @override
  State<_SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<_SignInView> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _displayName = TextEditingController();

  String? _emailError;
  String? _passwordError;
  String? _nameError;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  /// Validates every field at once so the user sees all the problems, not the
  /// first one, then re-tries and sees the second.
  bool _validate() {
    setState(() {
      _emailError = AuthValidators.email(_email.text);
      _passwordError = AuthValidators.password(_password.text);
      _nameError = widget.isRegister
          ? AuthValidators.displayName(_displayName.text)
          : null;
    });
    return _emailError == null && _passwordError == null && _nameError == null;
  }

  void _submit() {
    if (!_validate()) return;

    final AuthCubit cubit = context.read<AuthCubit>();
    if (widget.isRegister) {
      cubit.register(
        email: _email.text,
        password: _password.text,
        displayName: _displayName.text,
      );
    } else {
      cubit.login(email: _email.text, password: _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool isRegister = widget.isRegister;

    return Scaffold(
      backgroundColor: colors.bgCanvas,
      appBar: AppBar(title: Text(isRegister ? 'Create account' : 'Log in')),
      body: BlocConsumer<AuthCubit, AuthState>(
        listenWhen: (AuthState a, AuthState b) =>
            a.succeeded != b.succeeded ||
            a.needsProfileSetup != b.needsProfileSetup ||
            a.failure != b.failure,
        listener: (BuildContext context, AuthState state) {
          if (state.needsProfileSetup) {
            context.push('/auth/setup');
          } else if (state.succeeded) {
            // The router's guard sends a signed-in user to the shell; `go`
            // clears the auth stack so back can't return to it.
            context.go('/timer');
          }

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
                isRegister ? 'Welcome to CubeClash' : 'Welcome back',
                style: AppTypography.h2.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.x3),
              if (isRegister) ...<Widget>[
                AppTextField(
                  label: 'Display name',
                  controller: _displayName,
                  hintText: 'How others see you',
                  errorText: _nameError,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const <String>[AutofillHints.username],
                  maxLength: 24,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppTextField(
                label: 'Email',
                controller: _email,
                hintText: 'you@example.com',
                errorText: _emailError,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Password',
                controller: _password,
                obscureText: _obscure,
                errorText: _passwordError,
                textInputAction: TextInputAction.done,
                autofillHints: <String>[
                  isRegister
                      ? AutofillHints.newPassword
                      : AutofillHints.password,
                ],
                onSubmitted: (_) => _submit(),
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  color: colors.textMuted,
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                ),
              ),
              if (isRegister) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'At least 8 characters. Length beats punctuation.',
                  style:
                      AppTypography.caption.copyWith(color: colors.textMuted),
                ),
              ],
              const SizedBox(height: AppSpacing.x3),
              AppButton(
                label: isRegister ? 'Create account' : 'Log in',
                isLoading: state.isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.ghost(
                label: isRegister
                    ? 'I already have an account'
                    : 'Create an account instead',
                expand: true,
                onPressed: () => context.pushReplacement(
                  isRegister ? '/auth/login' : '/auth/register',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
