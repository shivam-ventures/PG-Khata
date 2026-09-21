import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/list_row_card.dart';
import '../../../../shared/widgets/pg_context_bar.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../dashboard/application/dashboard_providers.dart';
import '../../application/payments_providers.dart';
import '../../domain/rent_payment.dart';
import '../widgets/void_payment_dialog.dart';
import 'widgets/collect_rent_dialog.dart';

/// The Manager's rent-collection list for their current PG. Mirrors
/// `Manager Payments.dc.html`. Rendered inside [RoleShell]: page content only.
class ManagerPaymentsScreen extends ConsumerWidget {
  const ManagerPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyId = ref.watch(managerSelectedPgIdProvider);
    final paymentsAsync = ref.watch(latestPaymentsProvider(propertyId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space4,
            AppSpacing.space4,
            AppSpacing.space4,
            0,
          ),
          child: Text(
            'Collect Rent',
            style: AppTextStyles.screenTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const PgContextBar(),
        Expanded(
          child: AsyncValueView(
            value: paymentsAsync,
            onRetry: () => ref.invalidate(latestPaymentsProvider(propertyId)),
            loading: (context) => const _PaymentsSkeleton(),
            data: (context, payments) => _CollectRentBody(payments: payments),
          ),
        ),
      ],
    );
  }
}

class _CollectRentBody extends ConsumerWidget {
  const _CollectRentBody({required this.payments});

  final List<RentPayment> payments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (payments.isEmpty) {
      return const EmptyState(
        icon: Icons.payments_outlined,
        title: 'No tenants to collect from here yet',
        message: 'Rent rows show up once tenants are assigned a bed.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: [
        for (final payment in payments)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space2),
            child: ListRowCard(
              title: payment.tenantName,
              subtitle: payment.room,
              onOverflow: payment.method == null
                  ? null
                  : () => showVoidPaymentDialog(context, ref, payment: payment),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyFormatter.rupees(payment.amount),
                    style: AppTextStyles.rowTitle.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  if (payment.status.isCollectable)
                    ElevatedButton(
                      onPressed: () => showCollectRentDialog(
                        context,
                        payment: payment,
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: const Text('Collect'),
                    )
                  else
                    // A capped width, not Flexible — the chip sits beside
                    // `title`'s own Expanded in ListRowCard's row, and two
                    // competing flex children would each just get half the
                    // space regardless of how little either needs, which
                    // starves the tenant name for no reason. A fixed cap
                    // keeps this row's own width predictable instead.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 116),
                      child: StatusChip(
                        label: payment.status.label,
                        tone: payment.status.tone,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PaymentsSkeleton extends StatelessWidget {
  const _PaymentsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonBox(width: double.infinity, height: 60),
        SizedBox(height: AppSpacing.space2),
        SkeletonBox(width: double.infinity, height: 60),
        SizedBox(height: AppSpacing.space2),
        SkeletonBox(width: double.infinity, height: 60),
      ],
    );
  }
}
