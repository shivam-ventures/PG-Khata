import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/bed.dart';
import '../../domain/room.dart';

/// The `.room-card` pattern shared by Owner and Manager Rooms: a header
/// (room number + sharing type), one row per bed, and a rent footer.
/// [vacantBedAction] renders each vacant bed's trailing action — the two
/// roles offer different actions there, so this stays a builder.
class RoomCard extends StatelessWidget {
  const RoomCard({
    required this.room,
    required this.vacantBedAction,
    super.key,
  });

  final Room room;
  final Widget Function(Bed bed) vacantBedAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      margin: const EdgeInsets.only(bottom: AppSpacing.space3),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Room ${room.number}',
                style: AppTextStyles.rowTitle.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                room.sharingType.label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          Divider(color: context.appColors.divider, height: 1),
          const SizedBox(height: AppSpacing.space2),
          for (final bed in room.beds)
            _BedRow(bed: bed, vacantAction: vacantBedAction(bed)),
          const SizedBox(height: AppSpacing.space1),
          Divider(color: context.appColors.divider, height: 1),
          const SizedBox(height: AppSpacing.space2),
          Text(
            '${CurrencyFormatter.rupees(room.rentPerBed)} / bed',
            style: AppTextStyles.bodySmall.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BedRow extends StatelessWidget {
  const _BedRow({required this.bed, required this.vacantAction});

  final Bed bed;
  final Widget vacantAction;

  @override
  Widget build(BuildContext context) {
    final label = Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: bed.isVacant
                ? context.appColors.warning
                : context.appColors.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        Text(
          'Bed ${bed.label}',
          style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
        ),
      ],
    );

    // A vacant bed's actions (e.g. "Assign existing" + "Invite via link")
    // can be too wide to share a line with the bed label on a narrow phone
    // — wrap to keep both fully readable instead of squeezing them together.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.space1),
      child: bed.isVacant
          ? Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: AppSpacing.space1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [label, vacantAction],
            )
          : Row(
              children: [
                label,
                const Spacer(),
                Text(
                  bed.tenantName!,
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
                ),
              ],
            ),
    );
  }
}
