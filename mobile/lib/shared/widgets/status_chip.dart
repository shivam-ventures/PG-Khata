import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_text_styles.dart';
import 'semantic_tone.dart';

/// A soft-fill status pill — the Dart equivalent of `tokens-extra.css`'s
/// `.tag-success` / `.tag-warning` / `.tag-error` / `.tag-info` / `.tag-neutral`.
///
/// Every status in the app (payment status, complaint status, occupancy
/// health, ...) renders through this one widget so a given [SemanticTone]
/// always looks identical everywhere, per the design's own rule that status
/// colors are never hand-picked per screen.
class StatusChip extends StatelessWidget {
  const StatusChip({required this.label, required this.tone, super.key});

  final String label;
  final SemanticTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.background(context),
        borderRadius: BorderRadius.circular(AppRadius.md * 0.75),
      ),
      child: Text(
        label,
        style: AppTextStyles.tagLabel.copyWith(color: tone.foreground(context)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
