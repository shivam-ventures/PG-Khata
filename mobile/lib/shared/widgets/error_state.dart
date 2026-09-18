import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'primary_button.dart';
import 'semantic_tone.dart';

/// A friendly retry surface for a failed load — repositories return a typed
/// [AppFailure] with a user-facing message (see `core/errors`), so this
/// widget never has to guess how to phrase a raw exception.
class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space6,
        vertical: AppSpacing.space8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: SemanticTone.danger.background(context),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(
              Icons.error_outline,
              size: 24,
              color: SemanticTone.danger.foreground(context),
            ),
          ),
          const SizedBox(height: AppSpacing.space4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.space4),
            PrimaryButton(label: 'Try again', onPressed: onRetry),
          ],
        ],
      ),
    );
  }
}
