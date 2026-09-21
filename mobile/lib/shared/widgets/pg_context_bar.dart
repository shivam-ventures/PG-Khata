import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/dashboard/application/dashboard_providers.dart';
import '../../features/properties/application/properties_providers.dart';
import '../../features/properties/domain/property.dart';

/// The Manager's "which PG am I looking at" strip. Manager Today isn't the
/// only screen scoped to [managerSelectedPgIdProvider] — Payments, Rooms,
/// Tenants and Complaints all read the same selection — but Today used to
/// be the only place that *showed* it or let a Manager switch it. A manager
/// with more than one PG who opened, say, Tenants directly from More had no
/// way to tell which PG's roster they were looking at. This bar goes at the
/// top of every Manager screen instead, so the context is always visible
/// and switchable, not just from Today.
class PgContextBar extends ConsumerWidget {
  const PgContextBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(managerSelectedPgIdProvider);
    final propertiesAsync = ref.watch(propertiesProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space4,
        vertical: AppSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceAlt,
        border: Border(bottom: BorderSide(color: context.appColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          propertiesAsync.when(
            data: (properties) =>
                _Switcher(properties: properties, currentId: currentId),
            loading: () => Text(
              currentId,
              style: AppTextStyles.rowTitle.copyWith(fontSize: 13),
            ),
            error: (_, _) => Text(
              currentId,
              style: AppTextStyles.rowTitle.copyWith(fontSize: 13),
            ),
          ),
          Text(
            'Managing this PG',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Switcher extends ConsumerWidget {
  const _Switcher({required this.properties, required this.currentId});

  final List<Property> properties;
  final String currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (properties.isEmpty) {
      return Text(currentId, style: AppTextStyles.rowTitle.copyWith(fontSize: 13));
    }
    final current = properties.firstWhere(
      (p) => p.id == currentId,
      orElse: () => properties.first,
    );
    return PopupMenuButton<String>(
      initialValue: currentId,
      onSelected: (id) =>
          ref.read(managerSelectedPgIdProvider.notifier).select(id),
      itemBuilder: (context) => [
        for (final property in properties)
          PopupMenuItem(value: property.id, child: Text(property.name)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: context.appColors.divider),
          borderRadius: AppRadius.smAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current.name,
              style: AppTextStyles.rowTitle.copyWith(fontSize: 13),
            ),
            const SizedBox(width: AppSpacing.space1),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }
}
