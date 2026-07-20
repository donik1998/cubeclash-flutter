import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/solve_result.dart';
import '../../domain/entities/wca_event.dart';
import '../../domain/usecases/format_result.dart';

/// What the user entered by hand.
class ManualResult {
  const ManualResult({this.moveCount, this.solvedCount, this.attemptedCount});

  final int? moveCount;
  final int? solvedCount;
  final int? attemptedCount;
}

/// Captures a result the stopwatch cannot produce.
///
/// Two events need it, for different reasons:
///
///   * **Fewest Moves** — the result is a solution length. There is a clock on
///     an FMC attempt (one hour, Regulation E2) but it is not what you are
///     measured on, so the screen asks for a move count and treats the
///     duration as incidental.
///   * **Multi-Blind** — the attempt *is* timed, but `54:22` is not a result
///     without `11/13` beside it (Regulation 9f12), so the sheet opens the
///     moment the clock stops and the solve is not written until it closes.
///
/// Validation is real rather than cosmetic: a Multi-Blind attempt of fewer
/// than two cubes is not a valid attempt at all under 9b5, and solving more
/// cubes than you attempted is not a typo worth saving.
class ManualResultSheet extends StatefulWidget {
  const ManualResultSheet({
    super.key,
    required this.event,
    required this.elapsedMs,
    required this.onSubmit,
    required this.onCancel,
  });

  final WcaEvent event;

  /// The measured attempt duration, if the clock ran.
  final int elapsedMs;

  final ValueChanged<ManualResult> onSubmit;
  final VoidCallback onCancel;

  static Future<void> show(
    BuildContext context, {
    required WcaEvent event,
    required int elapsedMs,
    required ValueChanged<ManualResult> onSubmit,
    required VoidCallback onCancel,
  }) async {
    bool submitted = false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.bgSurface,
      isScrollControlled: true,
      // Dismissing without entering anything is a real choice — the attempt
      // simply is not recorded — but it must be deliberate, because a stray
      // backdrop tap after a 54-minute Multi-Blind attempt would throw the
      // whole thing away.
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (BuildContext sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: ManualResultSheet(
          event: event,
          elapsedMs: elapsedMs,
          onSubmit: (ManualResult result) {
            submitted = true;
            Navigator.of(sheetContext).pop();
            onSubmit(result);
          },
          onCancel: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );

    if (!submitted) onCancel();
  }

  @override
  State<ManualResultSheet> createState() => _ManualResultSheetState();
}

class _ManualResultSheetState extends State<ManualResultSheet> {
  final TextEditingController _primary = TextEditingController();
  final TextEditingController _secondary = TextEditingController();

  bool get _isMulti => widget.event.resultKind == ResultKind.multiBlind;

  int? get _primaryValue => int.tryParse(_primary.text.trim());
  int? get _secondaryValue => int.tryParse(_secondary.text.trim());

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  /// `null` when valid; the message to show otherwise.
  String? get _error {
    if (_isMulti) {
      final int? solved = _primaryValue;
      final int? attempted = _secondaryValue;
      if (solved == null || attempted == null) return null;
      if (attempted < 2) return 'A Multi-Blind attempt is at least 2 cubes.';
      if (solved > attempted) {
        return 'You cannot solve more cubes than you attempted.';
      }
      return null;
    }
    final int? moves = _primaryValue;
    if (moves == null) return null;
    // The shortest known 3×3 solution is well above this; a single-digit
    // entry is a slip, not a world record.
    if (moves < 1) return 'A solution has at least one move.';
    if (moves > 999) return 'That is not a move count.';
    return null;
  }

  bool get _canSubmit {
    if (_error != null) return false;
    if (_isMulti) return _primaryValue != null && _secondaryValue != null;
    return _primaryValue != null;
  }

  void _submit() {
    if (!_canSubmit) return;
    widget.onSubmit(
      _isMulti
          ? ManualResult(
              solvedCount: _primaryValue,
              attemptedCount: _secondaryValue,
            )
          : ManualResult(moveCount: _primaryValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _isMulti ? 'How did it go?' : 'Your solution',
              style: AppTypography.title.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _isMulti
                  ? 'Attempt time ${FormatResult.formatTime(
                      widget.elapsedMs,
                      forceSecondsOnly: true,
                    )}.'
                  : '${widget.event.name} is scored on solution length, not '
                      'on the clock.',
              style: AppTypography.small.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_isMulti)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: _field(_primary, 'Solved', '11')),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _field(_secondary, 'Attempted', '13')),
                ],
              )
            else
              _field(_primary, 'Moves', '28'),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style:
                    AppTypography.caption.copyWith(color: colors.statusDanger),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppButton(
                    label: _isMulti ? 'Discard' : 'Cancel',
                    variant: AppButtonVariant.secondary,
                    onPressed: widget.onCancel,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'Record',
                    onPressed: _canSubmit ? _submit : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint) =>
      AppTextField(
        label: label,
        controller: controller,
        hintText: hint,
        autofocus: controller == _primary,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      );
}
