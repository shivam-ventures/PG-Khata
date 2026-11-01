import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_route.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/cta_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../application/properties_providers.dart';
import '../domain/property.dart';
import '../domain/property_metrics.dart';
import 'widgets/add_edit_property_dialog.dart';
import 'widgets/import_properties_dialog.dart';
import 'widgets/property_list_card.dart';

/// The Owner's portfolio list. Mirrors `Properties.dc.html`. Rendered inside
/// [RoleShell]: page content only.
class OwnerPropertiesScreen extends ConsumerWidget {
  const OwnerPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(propertiesProvider);
    final metricsAsync = ref.watch(propertyMetricsProvider);
    return AsyncValueView(
      value: properties,
      onRetry: () => ref.invalidate(propertiesProvider),
      loading: (context) => const _PropertiesSkeleton(),
      data: (context, data) => _PropertiesContent(
        properties: data,
        metrics: metricsAsync.value ?? const {},
      ),
    );
  }
}

class _PropertiesContent extends StatelessWidget {
  const _PropertiesContent({required this.properties, required this.metrics});

  final List<Property> properties;
  final Map<String, PropertyMetrics> metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final totalBeds = properties.fold<int>(
      0,
      (sum, p) => sum + (metrics[p.id]?.totalBeds ?? 0),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.ownerPgsSection,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontSize: 19),
                    ),
                    Text(
                      l10n.propertiesCountSummary(properties.length, totalBeds),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: context.appColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
          child: Column(
            children: [
              CtaCard(
                icon: Icons.add,
                title: l10n.ownerAddPg,
                subtitle: l10n.propertiesAddPgSubtitle,
                onTap: () => showAddEditPropertyDialog(context),
              ),
              const SizedBox(height: AppSpacing.space2),
              CtaCard(
                icon: Icons.upload_file_outlined,
                title: l10n.propertiesImportPgsTitle,
                subtitle: l10n.propertiesImportPgsSubtitle,
                onTap: () => showImportPropertiesDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: properties.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.home_work_outlined,
                    title: l10n.ownerNoPgsTitle,
                    message: l10n.ownerPropertiesEmptyMessage,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  children: [
                    for (final property in properties)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.space3,
                        ),
                        child: PropertyListCard(
                          property: property,
                          metrics: metrics[property.id] ?? PropertyMetrics.zero,
                          onManageRooms: () => context.push(
                            '${AppRoute.ownerRooms}?property=${property.id}',
                          ),
                          onEdit: () => showAddEditPropertyDialog(
                            context,
                            editing: property,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PropertiesSkeleton extends StatelessWidget {
  const _PropertiesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonLine(width: 160, height: 22),
        SizedBox(height: AppSpacing.space6),
        SkeletonBox(width: double.infinity, height: 60),
        SizedBox(height: AppSpacing.space4),
        SkeletonBox(width: double.infinity, height: 180),
        SizedBox(height: AppSpacing.space3),
        SkeletonBox(width: double.infinity, height: 180),
      ],
    );
  }
}
