import 'package:flutter/material.dart';

import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/widgets/semantic_tone.dart';
import '../../../domain/owner_dashboard_data.dart';

/// The "Needs your attention" warning card at the top of the Owner
/// Dashboard, listing [items] with a dot marker and a "View" link each.
/// [onView] decides what a given item's [AttentionItem.destination]
/// actually does — a real route for a destination that has a screen, a
/// "coming soon" notice otherwise.
class AttentionCard extends StatelessWidget {
  const AttentionCard({required this.items, required this.onView, super.key});

  final List<AttentionItem> items;
  final ValueChanged<String> onView;

  @override
  Widget build(BuildContext context) {
    final tone = SemanticTone.warning;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: tone.background(context),
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEEDS YOUR ATTENTION',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tone.foreground(context),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: AppSpacing.space2),
                    decoration: BoxDecoration(
                      color: tone.foreground(context),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.text,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => onView(item.destination),
                    child: const Text(
                      'View',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
