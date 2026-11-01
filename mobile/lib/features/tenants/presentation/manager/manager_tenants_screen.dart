import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_label_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/cta_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/list_row_card.dart';
import '../../../../shared/widgets/pg_context_bar.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../dashboard/application/dashboard_providers.dart';
import '../../../properties/application/properties_providers.dart';
import '../../application/tenants_providers.dart';
import '../../domain/tenant_record.dart';
import '../widgets/add_edit_manager_tenant_dialog.dart';
import '../widgets/import_tenants_dialog.dart';
import '../widgets/tenant_actions_sheet.dart';

/// Resolves a property's display name from the real roster — falling back
/// to the raw id only if the properties list hasn't loaded yet, so this
/// never drifts out of sync with what Owner Properties / [PgContextBar] show.
String _propertyName(WidgetRef ref, String propertyId) {
  final properties = ref.read(propertiesProvider).value;
  if (properties == null) return propertyId;
  for (final property in properties) {
    if (property.id == propertyId) return property.name;
  }
  return propertyId;
}

/// The Manager's tenant roster for their current PG. Mirrors `Manager
/// Tenants.dc.html`. Reached from Manager Today's "Add Tenant" quick action
/// or Manager Rooms' "Assign existing" link — not a bottom-nav tab (it's
/// reached via More in the design), so this provides its own [AppScaffold].
class ManagerTenantsScreen extends ConsumerStatefulWidget {
  const ManagerTenantsScreen({
    this.initialRoom,
    this.initialBed,
    this.autoOpenAdd = false,
    super.key,
  });

  final String? initialRoom;
  final String? initialBed;
  final bool autoOpenAdd;

  @override
  ConsumerState<ManagerTenantsScreen> createState() =>
      _ManagerTenantsScreenState();
}

class _ManagerTenantsScreenState extends ConsumerState<ManagerTenantsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialRoom != null && widget.initialBed != null ||
        widget.autoOpenAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final propertyId = ref.read(managerSelectedPgIdProvider);
        showAddManagerTenantDialog(
          context,
          propertyId: propertyId,
          propertyName: _propertyName(ref, propertyId),
          initialRoomBed: widget.initialRoom != null
              ? '${widget.initialRoom} - ${widget.initialBed}'
              : null,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final propertyId = ref.watch(managerSelectedPgIdProvider);
    final tenantsAsync = ref.watch(tenantsProvider(propertyId));
    final pendingAsync = ref.watch(pendingTenantsProvider(propertyId));

    return AppScaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.space4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: context.appColors.divider),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  padding: EdgeInsets.zero,
                ),
                Text(
                  l10n.tenantsTitle,
                  style: AppTextStyles.screenTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const PgContextBar(),
          Expanded(
            child: AsyncValueView(
              value: tenantsAsync,
              onRetry: () => ref.invalidate(tenantsProvider(propertyId)),
              loading: (context) => const _TenantsSkeleton(),
              data: (context, tenants) => _TenantsBody(
                propertyId: propertyId,
                tenants: tenants,
                pending: pendingAsync.value ?? const [],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantsBody extends ConsumerWidget {
  const _TenantsBody({
    required this.propertyId,
    required this.tenants,
    required this.pending,
  });

  final String propertyId;
  final List<TenantRecord> tenants;
  final List<PendingTenant> pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final propertyName = _propertyName(ref, propertyId);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: [
        CtaCard(
          icon: Icons.person_add_alt,
          title: l10n.tenantsAddTenant,
          subtitle: l10n.tenantsAddManuallySubtitle,
          onTap: () => showAddManagerTenantDialog(
            context,
            propertyId: propertyId,
            propertyName: propertyName,
          ),
        ),
        const SizedBox(height: AppSpacing.space2),
        CtaCard(
          icon: Icons.upload_file_outlined,
          title: l10n.tenantsImportTitle,
          subtitle: l10n.propertiesImportPgsSubtitle,
          onTap: () => showImportTenantsDialog(
            context,
            propertyId: propertyId,
            propertyName: propertyName,
          ),
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
                onAssign: () => showAddManagerTenantDialog(
                  context,
                  propertyId: propertyId,
                  propertyName: propertyName,
                  pending: person,
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.space4),
        if (tenants.isEmpty)
          EmptyState(
            icon: Icons.people_outline,
            title: l10n.managerTenantsEmptyTitle,
            message: l10n.managerTenantsEmptyMessage,
          )
        else
          for (final tenant in tenants)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: ListRowCard(
                title: tenant.name,
                subtitle:
                    '${tenant.roomBed} · ${CurrencyFormatter.rupees(tenant.rent)}'
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: context.appColors.info100,
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
                  l10n.tenantsPendingPhoneSelfSignup(person.phone),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          PrimaryButton(
            label: l10n.tenantsAssignBed,
            onPressed: onAssign,
            expand: false,
          ),
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
        SizedBox(height: AppSpacing.space2),
        SkeletonBox(width: double.infinity, height: 60),
      ],
    );
  }
}
