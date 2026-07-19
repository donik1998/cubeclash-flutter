import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// The three states every list/async screen must handle.
///
/// House rule (docs → implementation prompt § 8): **no screen ships with only
/// the happy path.** If a screen loads data, it renders [LoadingState] while
/// in flight, [ErrorState] on failure and [EmptyState] when the result set is
/// empty — never a blank scaffold.

/// Centred spinner. Use while first-loading; for pagination use a small
/// trailing indicator instead so the list doesn't disappear.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircularProgressIndicator(color: colors.brandPrimary),
          if (message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            Text(
              message!,
              style: AppTypography.small.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Nothing here yet" — with an optional call to action that gets the user out
/// of the empty state (e.g. "Do your first solve").
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _StateScaffold(
        icon: icon,
        iconColor: context.colors.textMuted,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}

/// Failure state. [onRetry] is strongly encouraged — a dead end with no way
/// back is worse than the error itself.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => _StateScaffold(
        icon: Icons.error_outline,
        iconColor: context.colors.statusDanger,
        title: title,
        message: message,
        actionLabel: onRetry == null ? null : retryLabel,
        onAction: onRetry,
      );
}

/// Shared layout for [EmptyState] and [ErrorState].
class _StateScaffold extends StatelessWidget {
  const _StateScaffold({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(color: colors.textPrimary),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style:
                    AppTypography.small.copyWith(color: colors.textSecondary),
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              AppButton.secondary(
                label: actionLabel!,
                onPressed: onAction,
                size: AppButtonSize.medium,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
