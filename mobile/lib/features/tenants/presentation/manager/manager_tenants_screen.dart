import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/cta_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/list_row_card.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../dashboard/application/dashboard_providers.dart';
import '../../application/tenants_providers.dart';
import '../../domain/tenant_record.dart';
import '../widgets/add_edit_manager_tenant_dialog.dart';
import '../widgets/move_out_dialog.dart';

const _pgNames = {'hsr': 'HSR PG', 'ind': 'Indiranagar PG'};

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
          propertyName: _pgNames[propertyId] ?? propertyId,
          initialRoomBed: widget.initialRoom != null
              ? '${widget.initialRoom} - ${widget.initialBed}'
              : null,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  'Tenants',
                  style: AppTextStyles.screenTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
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
    final propertyName = _pgNames[propertyId] ?? propertyId;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: [
        CtaCard(
          icon: Icons.person_add_alt,
          title: 'Add tenant',
          subtitle: 'Manually add someone with a known bed & rent',
          onTap: () => showAddManagerTenantDialog(
            context,
            propertyId: propertyId,
            propertyName: propertyName,
          ),
        ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.space4),
          Text(
            'SELF-REGISTERED — NEEDS A BED',
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
          const EmptyState(
            icon: Icons.people_outline,
            title: 'No tenants yet',
            message: 'Add your first tenant above.',
          )
        else
          for (final tenant in tenants)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: ListRowCard(
                title: tenant.name,
                subtitle:
                    '${tenant.roomBed} · ${CurrencyFormatter.rupees(tenant.rent)}',
                trailing: StatusChip(
                  label: tenant.status.label,
                  tone: tenant.status.tone,
                ),
                onOverflow: tenant.canMoveOut
                    ? () => showMoveOutDialog(
                        context,
                        ref,
                        tenantId: tenant.id,
                        tenantName: tenant.name,
                        propertyId: propertyId,
                      )
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
                  '${person.phone} · joined via self-signup',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          PrimaryButton(
            label: 'Assign bed',
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
