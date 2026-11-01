import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/cta_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/pg_context_bar.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../dashboard/application/dashboard_providers.dart';
import '../../../properties/application/properties_providers.dart';
import '../../application/announcements_providers.dart';
import '../owner/owner_announcements_screen.dart' show buildAnnouncementCards;
import '../widgets/create_announcement_dialog.dart';

/// The Manager's announcement history + posting for their current PG.
/// Mirrors [OwnerAnnouncementsScreen] but scoped to
/// [managerSelectedPgIdProvider] via [PgContextBar] instead of a property
/// dropdown, matching every other Manager screen.
class ManagerAnnouncementsScreen extends ConsumerWidget {
  const ManagerAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final propertyId = ref.watch(managerSelectedPgIdProvider);
    final properties = ref.watch(propertiesProvider).value ?? const [];
    var propertyName = l10n.managerAnnouncementsFallbackPg;
    for (final property in properties) {
      if (property.id == propertyId) {
        propertyName = property.name;
        break;
      }
    }
    final announcementsAsync = ref.watch(announcementsProvider(propertyId));

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
                  l10n.announcementsTitle,
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
              value: announcementsAsync,
              onRetry: () => ref.invalidate(announcementsProvider(propertyId)),
              loading: (context) => const _ManagerAnnouncementsSkeleton(),
              data: (context, announcements) => ListView(
                padding: const EdgeInsets.all(AppSpacing.space4),
                children: [
                  CtaCard(
                    icon: Icons.campaign_outlined,
                    title: l10n.announcementsNewTitle,
                    subtitle: l10n.announcementsNewSubtitle(propertyName),
                    onTap: propertyId.isEmpty
                        ? null
                        : () => showCreateAnnouncementDialog(
                            context,
                            ref,
                            propertyId: propertyId,
                            propertyName: propertyName,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  if (announcements.isEmpty)
                    EmptyState(
                      icon: Icons.campaign_outlined,
                      title: l10n.announcementsEmptyTitle,
                      message: l10n.announcementsEmptyMessage,
                    )
                  else
                    ...buildAnnouncementCards(
                      announcements: announcements,
                      propertyId: propertyId,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerAnnouncementsSkeleton extends StatelessWidget {
  const _ManagerAnnouncementsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonBox(width: double.infinity, height: 56),
        SizedBox(height: AppSpacing.space4),
        SkeletonBox(width: double.infinity, height: 90),
      ],
    );
  }
}
