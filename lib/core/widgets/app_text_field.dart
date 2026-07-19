import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Label + field, `bg/surface` on a `border/strong` outline, radius 12.
///
/// The label sits **above** the field rather than floating inside it — the
/// design system treats them as two stacked elements, and it keeps the field
/// height stable as content changes.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.maxLength,
    this.suffix,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;

  /// Non-null puts the field in its error state and renders the message below.
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final int? maxLength;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool hasError = errorText != null;

    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: c),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTypography.label.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          enabled: enabled,
          autofocus: autofocus,
          maxLength: maxLength,
          style: AppTypography.body.copyWith(color: colors.textPrimary),
          cursorColor: colors.brandPrimary,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.body.copyWith(color: colors.textMuted),
            filled: true,
            fillColor: enabled ? colors.bgSurface : colors.bgSurfaceAlt,
            counterText: '',
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            enabledBorder:
                border(hasError ? colors.statusDanger : colors.borderStrong),
            focusedBorder:
                border(hasError ? colors.statusDanger : colors.brandPrimary),
            disabledBorder: border(colors.borderSubtle),
            border: border(colors.borderStrong),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: AppTypography.caption.copyWith(color: colors.statusDanger),
          ),
        ],
      ],
    );
  }
}
