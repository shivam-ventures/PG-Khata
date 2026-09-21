import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/semantic_tone.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/property.dart';
import '../../domain/property_metrics.dart';

/// The `.prop-card` pattern on `Properties.dc.html`: name/address, an open
/// complaints chip, an occupancy bar, rent/manager stats, and two actions.
class PropertyListCard extends StatelessWidget {
  const PropertyListCard({
    required this.property,
    required this.metrics,
    required this.onManageRooms,
    required this.onEdit,
    super.key,
  });

  final Property property;
  final PropertyMetrics metrics;
  final VoidCallback onManageRooms;
  final VoidCallback onEdit;

  SemanticTone get _complaintsTone => switch (metrics.openComplaints) {
    0 => SemanticTone.success,
    1 || 2 => SemanticTone.warning,
    _ => SemanticTone.danger,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: context.appColors.divider),
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadows.of(theme.brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      property.name,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                    ),
                    Text(
                      property.address,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.appColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: '${metrics.openComplaints} open',
                tone: _complaintsTone,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Occupancy',
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              Text(
                '${metrics.occupiedBeds}/${metrics.totalBeds}',
                style: AppTextStyles.rowTitle.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space1),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: metrics.occupancyFraction,
              minHeight: 6,
              backgroundColor: context.appColors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Rent',
                  value:
                      '${CurrencyFormatter.rupees(metrics.rentCollected)} / ${CurrencyFormatter.rupees(metrics.rentExpected)}',
                ),
              ),
              Expanded(
                child: _Stat(label: 'Manager', value: property.managerName),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Divider(color: context.appColors.divider, height: 1),
          const SizedBox(height: AppSpacing.space3),
          Row(
            children: [
              TextButton(
                onPressed: onManageRooms,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                ),
                child: const Text(
                  'Manage rooms & beds',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.kicker.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        Text(value, style: AppTextStyles.rowTitle.copyWith(fontSize: 13)),
      ],
    );
  }
}
