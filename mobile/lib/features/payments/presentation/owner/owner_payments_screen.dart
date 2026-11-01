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
import '../../../../shared/widgets/semantic_tone.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../properties/application/properties_providers.dart';
import '../../../properties/domain/property.dart';
import '../../application/payments_providers.dart';
import '../../domain/payment_status.dart';
import '../../domain/rent_payment.dart';
import '../widgets/void_payment_dialog.dart';
import 'widgets/record_payment_dialog.dart';
import 'widgets/resolve_dispute_dialog.dart';

/// The Owner's whole-portfolio rent ledger. Mirrors `Owner Payments.dc.html`.
/// Reached from Owner's "More" menu — not a bottom-nav tab, so this provides
/// its own [AppScaffold].
class OwnerPaymentsScreen extends ConsumerStatefulWidget {
  const OwnerPaymentsScreen({super.key});

  @override
  ConsumerState<OwnerPaymentsScreen> createState() =>
      _OwnerPaymentsScreenState();
}

class _OwnerPaymentsScreenState extends ConsumerState<OwnerPaymentsScreen> {
  String _propertyFilter = 'all';
  PaymentStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final propertiesAsync = ref.watch(propertiesProvider);
    final paymentsAsync = ref.watch(latestPaymentsProvider(null));

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.ownerPayments,
                        style: AppTextStyles.screenTitle.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        l10n.ownerPaymentsSubtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: context.appColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: propertiesAsync,
              loading: (context) => const _PaymentsSkeleton(),
              data: (context, properties) => AsyncValueView(
                value: paymentsAsync,
                onRetry: () => ref.invalidate(latestPaymentsProvider(null)),
                loading: (context) => const _PaymentsSkeleton(),
                data: (context, payments) => _OwnerPaymentsBody(
                  properties: properties,
                  payments: payments,
                  propertyFilter: _propertyFilter,
                  statusFilter: _statusFilter,
                  onPropertyFilterChanged: (value) =>
                      setState(() => _propertyFilter = value),
                  onStatusFilterChanged: (value) =>
                      setState(() => _statusFilter = value),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerPaymentsBody extends ConsumerWidget {
  const _OwnerPaymentsBody({
    required this.properties,
    required this.payments,
    required this.propertyFilter,
    required this.statusFilter,
    required this.onPropertyFilterChanged,
    required this.onStatusFilterChanged,
  });

  final List<Property> properties;
  final List<RentPayment> payments;
  final String propertyFilter;
  final PaymentStatus? statusFilter;
  final ValueChanged<String> onPropertyFilterChanged;
  final ValueChanged<PaymentStatus?> onStatusFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // For a `partial` period, `amount` is the confirmed-paid portion (real
    // money in hand), not the full rent — so it belongs in `collected`, and
    // the still-owed remainder (`outstandingAmount`) belongs in `expected`
    // alongside pending/overdue, not the raw `amount`. See
    // RentPayment.outstandingAmount / backend migration 33.
    final collected =
        _sum(payments, PaymentStatus.paid) + _sum(payments, PaymentStatus.partial);
    final pending = _sum(payments, PaymentStatus.pending);
    final overdue = _sum(payments, PaymentStatus.overdue);
    final partialOutstanding = payments
        .where((p) => p.status == PaymentStatus.partial)
        .fold<int>(0, (total, p) => total + p.outstandingAmount);
    final needsReview =
        _sum(payments, PaymentStatus.awaitingConfirmation) +
        _sum(payments, PaymentStatus.disputed);
    final needsReviewCount =
        _count(payments, PaymentStatus.awaitingConfirmation) +
        _count(payments, PaymentStatus.disputed);
    final expected = collected + pending + overdue + partialOutstanding;
    final collectionRate = expected == 0
        ? 0
        : (collected / expected * 100).round();

    final filtered = payments.where((p) {
      final matchesProperty =
          propertyFilter == 'all' || p.propertyName == propertyFilter;
      final matchesStatus = statusFilter == null || p.status == statusFilter;
      return matchesProperty && matchesStatus;
    }).toList();

    final paymentStats = [
      StatCard(
        icon: Icons.check_circle_outline,
        label: l10n.paymentsStatCollected,
        value: CurrencyFormatter.rupees(collected),
        sub: l10n.paymentsStatCollectedSub,
        tone: SemanticTone.success,
      ),
      StatCard(
        icon: Icons.hourglass_bottom,
        label: l10n.paymentsStatPending,
        value: CurrencyFormatter.rupees(pending),
        sub: l10n.statPendingRentSub(_count(payments, PaymentStatus.pending)),
        tone: SemanticTone.warning,
      ),
      StatCard(
        icon: Icons.warning_amber_rounded,
        label: l10n.paymentsStatOverdue,
        value: CurrencyFormatter.rupees(overdue),
        sub: l10n.statPendingRentSub(_count(payments, PaymentStatus.overdue)),
        tone: SemanticTone.danger,
      ),
      StatCard(
        icon: Icons.bar_chart,
        label: l10n.paymentsStatCollectionRate,
        value: '$collectionRate%',
        sub: l10n.paymentsStatCollectionRateSub,
        tone: SemanticTone.accent,
      ),
      StatCard(
        icon: Icons.flag_outlined,
        label: l10n.paymentsStatNeedsReview,
        value: CurrencyFormatter.rupees(needsReview),
        sub: l10n.statPendingRentSub(needsReviewCount),
        tone: SemanticTone.info,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: [
        CtaCard(
          icon: Icons.add,
          title: l10n.paymentsRecordPaymentTitle,
          subtitle: l10n.paymentsRecordPaymentSubtitle,
          onTap: () => showRecordPaymentDialog(context, payments: payments),
        ),
        const SizedBox(height: AppSpacing.space4),
        // A fixed childAspectRatio here (as the Owner Dashboard's and Owner
        // Reports' stat grids used to) gets outgrown by real,
        // locale/font-dependent stat text — StatCard already sizes itself
        // to its own content, so pairing plain Rows lets that work instead
        // of re-guessing a magic ratio.
        for (var i = 0; i < paymentStats.length; i += 2)
          Padding(
            padding: EdgeInsets.only(
              bottom: i + 2 < paymentStats.length ? AppSpacing.space3 : 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: paymentStats[i]),
                const SizedBox(width: AppSpacing.space3),
                if (i + 1 < paymentStats.length)
                  Expanded(child: paymentStats[i + 1])
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.space4),
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
        const SizedBox(height: AppSpacing.space2),
        DropdownButtonFormField<PaymentStatus?>(
          isExpanded: true,
          initialValue: statusFilter,
          decoration: InputDecoration(labelText: l10n.commonStatus),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(l10n.paymentsFilterAllStatuses),
            ),
            for (final status in PaymentStatus.values)
              DropdownMenuItem(value: status, child: Text(status.labelFor(l10n))),
          ],
          onChanged: onStatusFilterChanged,
        ),
        const SizedBox(height: AppSpacing.space4),
        if (filtered.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: l10n.paymentsEmptyTitle,
            message: l10n.paymentsEmptyMessage,
          )
        else
          for (final payment in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: ListRowCard(
                title: payment.tenantName,
                subtitle: l10n.paymentsRowSubtitleDue(
                  payment.propertyName,
                  payment.room,
                  DateLabelFormatter.short(payment.dueDate),
                ),
                onOverflow: switch (payment.status) {
                  PaymentStatus.disputed => () => showResolveDisputeDialog(
                    context,
                    ref,
                    payment: payment,
                  ),
                  _ when payment.method != null => () =>
                      showVoidPaymentDialog(context, ref, payment: payment),
                  _ => null,
                },
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // What's still owed for pending/overdue/partial; what
                      // was paid/claimed otherwise. See
                      // RentPayment.outstandingAmount.
                      CurrencyFormatter.rupees(
                        payment.status.isCollectable
                            ? payment.outstandingAmount
                            : payment.amount,
                      ),
                      style: AppTextStyles.rowTitle.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    StatusChip(
                      label: payment.status.labelFor(l10n),
                      tone: payment.status.tone,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  static int _sum(List<RentPayment> payments, PaymentStatus status) =>
      payments
          .where((p) => p.status == status)
          .fold(0, (total, p) => total + p.amount);

  static int _count(List<RentPayment> payments, PaymentStatus status) =>
      payments.where((p) => p.status == status).length;
}

class _PaymentsSkeleton extends StatelessWidget {
  const _PaymentsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonBox(width: double.infinity, height: 60),
        SizedBox(height: AppSpacing.space4),
        SkeletonBox(width: double.infinity, height: 100),
        SizedBox(height: AppSpacing.space3),
        SkeletonBox(width: double.infinity, height: 60),
      ],
    );
  }
}
