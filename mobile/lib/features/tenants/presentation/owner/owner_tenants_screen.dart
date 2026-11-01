import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_label_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/cta_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/list_row_card.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../properties/application/properties_providers.dart';
import '../../../properties/domain/property.dart';
import '../../application/tenants_providers.dart';
import '../../domain/tenant_record.dart';
import '../widgets/add_edit_owner_tenant_dialog.dart';
import '../widgets/tenant_actions_sheet.dart';

/// The Owner's whole-portfolio tenant roster. Mirrors `Owner Tenants.dc.html`.
/// Rendered inside [RoleShell]: page content only.
class OwnerTenantsScreen extends ConsumerStatefulWidget {
  const OwnerTenantsScreen({super.key});

  @override
  ConsumerState<OwnerTenantsScreen> createState() => _OwnerTenantsScreenState();
}

class _OwnerTenantsScreenState extends ConsumerState<OwnerTenantsScreen> {
  final _searchController = TextEditingController();
  String _propertyFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final propertiesAsync = ref.watch(propertiesProvider);
    final tenantsAsync = ref.watch(tenantsProvider(null));
    final pendingAsync = ref.watch(pendingTenantsProvider(null));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.tenantsTitle,
                style: AppTextStyles.screenTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              tenantsAsync.when(
                data: (tenants) => Text(
                  l10n.tenantsCountAcrossPortfolio(tenants.length),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView(
            value: propertiesAsync,
            loading: (context) => const _TenantsSkeleton(),
            data: (context, properties) => AsyncValueView(
              value: tenantsAsync,
              onRetry: () => ref.invalidate(tenantsProvider(null)),
              loading: (context) => const _TenantsSkeleton(),
              data: (context, tenants) => _TenantsBody(
                properties: properties,
                tenants: tenants,
                pending: pendingAsync.value ?? const [],
                searchController: _searchController,
                propertyFilter: _propertyFilter,
                onPropertyFilterChanged: (value) =>
                    setState(() => _propertyFilter = value),
                onSearchChanged: () => setState(() {}),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TenantsBody extends ConsumerWidget {
  const _TenantsBody({
    required this.properties,
    required this.tenants,
    required this.pending,
    required this.searchController,
    required this.propertyFilter,
    required this.onPropertyFilterChanged,
    required this.onSearchChanged,
  });

  final List<Property> properties;
  final List<TenantRecord> tenants;
  final List<PendingTenant> pending;
  final TextEditingController searchController;
  final String propertyFilter;
  final ValueChanged<String> onPropertyFilterChanged;
  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final query = searchController.text.trim().toLowerCase();
    final filtered = tenants.where((t) {
      final matchesProperty =
          propertyFilter == 'all' || t.propertyName == propertyFilter;
      final matchesSearch =
          query.isEmpty ||
          t.name.toLowerCase().contains(query) ||
          t.phone.contains(query);
      return matchesProperty && matchesSearch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: [
        CtaCard(
          icon: Icons.person_add_alt,
          title: l10n.tenantsAddTenant,
          subtitle: properties.isEmpty
              ? l10n.tenantsAddNeedsPgFirst
              : l10n.tenantsAddManuallySubtitle,
          onTap: properties.isEmpty
              ? null
              : () => showAddOwnerTenantDialog(context, properties: properties),
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space4),
          Text(
            l10n.tenantsSelfRegisteredHeader,
            style: AppTextStyles.kickerUppercase.copyWith(
              color: context.appColors.info,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          for (final person in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: _PendingCard(
                person: person,
                onAssign: () => showAddOwnerTenantDialog(
                  context,
                  properties: properties,
                  pending: person,
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.space4),
        AppTextField(
          label: l10n.tenantsSearchLabel,
          controller: searchController,
          onChanged: (_) => onSearchChanged(),
        ),
        const SizedBox(height: AppSpacing.space2),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: propertyFilter,
          decoration: InputDecoration(labelText: l10n.commonPg),
          items: [
            DropdownMenuItem(value: 'all', child: Text(l10n.commonAllPgs)),
            for (final property in properties)
              DropdownMenuItem(
                value: property.name,
                child: Text(property.name),
              ),
          ],
          onChanged: (value) {
            if (value != null) onPropertyFilterChanged(value);
          },
        ),
        const SizedBox(height: AppSpacing.space4),
        if (filtered.isEmpty)
          EmptyState(
            icon: Icons.people_outline,
            title: l10n.tenantsEmptyMatchTitle,
            message: l10n.roomsEmptyMessage,
          )
        else
          for (final tenant in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: ListRowCard(
                title: tenant.name,
                subtitle:
                    '${tenant.propertyName} · ${tenant.roomBed} · '
                    '${CurrencyFormatter.rupees(tenant.rent)}'
                    '${tenant.depositAmount == null ? '' : l10n.tenantsDepositSuffix(CurrencyFormatter.rupees(tenant.depositAmount!))}'
                    '${tenant.moveOutDate == null ? '' : l10n.tenantsMovingOutSuffix(DateLabelFormatter.short(tenant.moveOutDate!))}',
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusChip(
                      label: tenant.status.labelFor(l10n),
                      tone: tenant.status.tone,
                    ),
                    if (tenant.depositSettlement != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: StatusChip(
                          label: tenant.depositSettlement!.labelFor(l10n),
                          tone: tenant.depositSettlement!.tone,
                        ),
                      ),
                  ],
                ),
                onOverflow:
                    (tenant.canGiveNotice ||
                        tenant.canCancelNotice ||
                        tenant.canMoveOut ||
                        tenant.canMarkDepositReturned)
                    ? () => showTenantActionsSheet(context, ref, tenant: tenant)
                    : null,
              ),
            ),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.person, required this.onAssign});

  final PendingTenant person;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tone = context.appColors.info100;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(person.name, style: AppTextStyles.rowTitle),
                Text(
                  l10n.tenantsPendingPropertyPhone(
                    person.propertyName,
                    person.phone,
                  ),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          PrimaryButton(label: l10n.tenantsAssign, onPressed: onAssign, expand: false),
        ],
      ),
    );
  }
}

class _TenantsSkeleton extends StatelessWidget {
  const _TenantsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonBox(width: double.infinity, height: 60),
        SizedBox(height: AppSpacing.space4),
        SkeletonBox(width: double.infinity, height: 60),
        SizedBox(height: AppSpacing.space2),
        SkeletonBox(width: double.infinity, height: 60),
      ],
    );
  }
}
