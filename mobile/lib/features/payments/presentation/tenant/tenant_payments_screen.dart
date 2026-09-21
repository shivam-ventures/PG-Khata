import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_label_formatter.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/list_row_card.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../tenants/application/tenants_providers.dart';
import '../../application/payments_providers.dart';
import '../../domain/payment_status.dart';
import '../../domain/rent_payment.dart';
import 'widgets/pay_rent_dialog.dart';

/// The Tenant's own rent screen. Mirrors `Tenant Payments.dc.html`.
/// Rendered inside [RoleShell]: page content only. Reads the *signed-in*
/// tenant's own record via [currentTenantRecordProvider] — see that
/// provider's doc comment for why this matters.
class TenantPaymentsScreen extends ConsumerWidget {
  const TenantPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(currentTenantRecordProvider);

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
            'Rent & Payments',
            style: AppTextStyles.screenTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: AsyncValueView(
            value: tenantAsync,
            onRetry: () => ref.invalidate(currentTenantRecordProvider),
            loading: (context) => const _TenantPaymentsSkeleton(),
            data: (context, tenant) => tenant == null
                ? const EmptyState(
                    icon: Icons.home_work_outlined,
                    title: 'No room assigned yet',
                    message:
                        "Once a manager assigns you a bed, your rent and "
                        "payment history will show up here.",
                  )
                : _TenantPaymentsForTenant(tenantId: tenant.id),
          ),
        ),
      ],
    );
  }
}

class _TenantPaymentsForTenant extends ConsumerWidget {
  const _TenantPaymentsForTenant({required this.tenantId});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(paymentHistoryProvider(tenantId));
    return AsyncValueView(
      value: historyAsync,
      onRetry: () => ref.invalidate(paymentHistoryProvider(tenantId)),
      loading: (context) => const _TenantPaymentsSkeleton(),
      data: (context, history) => _TenantPaymentsBody(history: history),
    );
  }
}

class _TenantPaymentsBody extends ConsumerWidget {
  const _TenantPaymentsBody({required this.history});

  final List<RentPayment> history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No rent record yet',
        message: "Your rent history will show up here once your first "
            "period is on record.",
      );
    }
    final current = history.first;
    // Only surface the separate confirm/dispute banner for an *older* cash
    // payment still awaiting confirmation — when it's the current period,
    // `_RentDueCard` itself renders the confirm/dispute action instead of
    // "Pay Rent", so a second banner for the same row would be redundant.
    RentPayment? awaitingCash;
    for (final payment in history) {
      if (payment.status == PaymentStatus.awaitingConfirmation &&
          payment.id != current.id) {
        awaitingCash = payment;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: [
        _RentDueCard(payment: current),
        if (awaitingCash != null) ...[
          const SizedBox(height: AppSpacing.space4),
          _PendingCashCard(payment: awaitingCash),
        ],
        const SizedBox(height: AppSpacing.space4),
        const SectionHeader(title: 'Payment history'),
        for (final payment in history)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space2),
            child: ListRowCard(
              title: DateLabelFormatter.monthYear(payment.periodMonth),
              subtitle: payment.paidDate != null
                  ? '${payment.method?.label ?? '—'} · '
                        '${DateLabelFormatter.short(payment.paidDate!)}'
                  : '— · Due ${DateLabelFormatter.short(payment.dueDate)}',
              trailing: StatusChip(
                label: payment.status.label,
                tone: payment.status.tone,
              ),
            ),
          ),
      ],
    );
  }
}

class _RentDueCard extends StatelessWidget {
  const _RentDueCard({required this.payment});

  final RentPayment payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSettled = payment.status == PaymentStatus.paid;
    final isAwaitingCash = payment.status == PaymentStatus.awaitingConfirmation;
    // A single Border can't mix per-side colors with a borderRadius (Flutter
    // asserts on that combination) — so the accent stripe is a separate
    // clipped strip inside a uniformly-bordered container instead. See
    // TenantHomeScreen's `_RentCard` for the same pattern.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.of(theme.brightness),
        border: Border.all(color: context.appColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: theme.colorScheme.primary),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  switch (payment.status) {
                    PaymentStatus.paid =>
                      'Room ${payment.room} · Paid for ${DateLabelFormatter.monthYear(payment.periodMonth)}',
                    PaymentStatus.awaitingConfirmation =>
                      'Room ${payment.room} · ${payment.method?.label ?? 'Payment'} recorded ${DateLabelFormatter.short(payment.paidDate!)}',
                    _ => 'Room ${payment.room} · Due ${DateLabelFormatter.short(payment.dueDate)}',
                  },
                  style: AppTextStyles.kickerUppercase.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.space1),
                Text(
                  CurrencyFormatter.rupees(payment.amount),
                  style: AppTextStyles.displayAmount.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.space2),
                if (isAwaitingCash)
                  _ConfirmDisputeRow(paymentId: payment.id)
                else if (!isSettled)
                  PrimaryButton(
                    label: 'Pay Rent',
                    expand: false,
                    onPressed: () => showPayRentDialog(context, payment: payment),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCashCard extends StatelessWidget {
  const _PendingCashCard({required this.payment});

  final RentPayment payment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.appColors.info100,
        borderRadius: AppRadius.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${payment.method?.label ?? 'Payment'} recorded by manager',
            style: AppTextStyles.kicker.copyWith(color: context.appColors.info700),
          ),
          const SizedBox(height: 2),
          Text(
            '${CurrencyFormatter.rupees(payment.amount)} on '
            '${DateLabelFormatter.short(payment.paidDate!)}',
            style: AppTextStyles.rowTitle,
          ),
          const SizedBox(height: AppSpacing.space2),
          Text(
            "Did you pay this? Confirming helps keep your rent record accurate.",
            style: AppTextStyles.bodySmall.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          _ConfirmDisputeRow(paymentId: payment.id),
        ],
      ),
    );
  }
}

class _ConfirmDisputeRow extends ConsumerWidget {
  const _ConfirmDisputeRow({required this.paymentId});

  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: SecondaryButton(
            label: "I didn't pay this",
            onPressed: () => disputePayment(ref, paymentId),
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        Expanded(
          child: PrimaryButton(
            label: 'Confirm',
            onPressed: () => confirmPayment(ref, paymentId),
          ),
        ),
      ],
    );
  }
}

class _TenantPaymentsSkeleton extends StatelessWidget {
  const _TenantPaymentsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonBox(width: double.infinity, height: 130),
        SizedBox(height: AppSpacing.space4),
        SkeletonBox(width: double.infinity, height: 60),
        SizedBox(height: AppSpacing.space2),
        SkeletonBox(width: double.infinity, height: 60),
      ],
    );
  }
}
