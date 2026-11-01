import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/relative_time_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/cta_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../properties/application/properties_providers.dart';
import '../../../properties/domain/property.dart';
import '../../application/announcements_providers.dart';
import '../../domain/announcement.dart';
import '../widgets/create_announcement_dialog.dart';

/// Owner's per-PG announcement history + posting. Unlike Complaints/Payments
/// (which show the whole portfolio filtered), announcements are inherently
/// one-PG-at-a-time — you post to a specific property's tenants, not "all of
/// them at once" — so this picks one PG rather than filtering a merged list.
class OwnerAnnouncementsScreen extends ConsumerStatefulWidget {
  const OwnerAnnouncementsScreen({super.key});

  @override
  ConsumerState<OwnerAnnouncementsScreen> createState() =>
      _OwnerAnnouncementsScreenState();
}

class _OwnerAnnouncementsScreenState
    extends ConsumerState<OwnerAnnouncementsScreen> {
  String? _propertyId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final propertiesAsync = ref.watch(propertiesProvider);

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
          Expanded(
            child: AsyncValueView(
              value: propertiesAsync,
              onRetry: () => ref.invalidate(propertiesProvider),
              loading: (context) => const _AnnouncementsSkeleton(),
              data: (context, properties) {
                if (properties.isEmpty) {
                  return EmptyState(
                    icon: Icons.campaign_outlined,
                    title: l10n.ownerAnnouncementsEmptyTitle,
                    message: l10n.ownerAnnouncementsEmptyMessage,
                  );
                }
                final selectedId = _propertyId ?? properties.first.id;
                final selected = properties.firstWhere(
                  (p) => p.id == selectedId,
                  orElse: () => properties.first,
                );
                return _AnnouncementsBody(
                  properties: properties,
                  selected: selected,
                  onPropertyChanged: (id) => setState(() => _propertyId = id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementsBody extends ConsumerWidget {
  const _AnnouncementsBody({
    required this.properties,
    required this.selected,
    required this.onPropertyChanged,
  });

  final List<Property> properties;
  final Property selected;
  final ValueChanged<String> onPropertyChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final announcementsAsync = ref.watch(announcementsProvider(selected.id));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: selected.id,
          decoration: InputDecoration(labelText: l10n.commonPg),
          items: [
            for (final property in properties)
              DropdownMenuItem(
                value: property.id,
                child: Text(property.name),
              ),
          ],
          onChanged: (value) {
            if (value != null) onPropertyChanged(value);
          },
        ),
        const SizedBox(height: AppSpacing.space4),
        CtaCard(
          icon: Icons.campaign_outlined,
          title: l10n.announcementsNewTitle,
          subtitle: l10n.announcementsNewSubtitle(selected.name),
          onTap: () => showCreateAnnouncementDialog(
            context,
            ref,
            propertyId: selected.id,
            propertyName: selected.name,
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        AsyncValueView(
          value: announcementsAsync,
          onRetry: () => ref.invalidate(announcementsProvider(selected.id)),
          loading: (context) => const _HistorySkeleton(),
          data: (context, announcements) => announcements.isEmpty
              ? EmptyState(
                  icon: Icons.campaign_outlined,
                  title: l10n.announcementsEmptyTitle,
                  message: l10n.announcementsEmptyMessage,
                )
              : Column(
                  children: buildAnnouncementCards(
                    announcements: announcements,
                    propertyId: selected.id,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Shared between [OwnerAnnouncementsScreen] (which filters/scopes a
/// property picker itself) and `ManagerAnnouncementsScreen` (which is
/// already scoped by [PgContextBar]) — the card list rendering is
/// otherwise identical.
List<Widget> buildAnnouncementCards({
  required List<Announcement> announcements,
  required String propertyId,
}) {
  return [
    for (final announcement in announcements)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.space2),
        child: _AnnouncementCard(
          announcement: announcement,
          propertyId: propertyId,
        ),
      ),
  ];
}

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard({required this.announcement, required this.propertyId});

  final Announcement announcement;
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: announcement.isExpired
            ? theme.colorScheme.surface.withValues(alpha: 0.6)
            : theme.colorScheme.surface,
        border: Border.all(color: context.appColors.divider),
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadows.of(theme.brightness),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(announcement.title, style: AppTextStyles.rowTitle),
                const SizedBox(height: 2),
                Text(announcement.body, style: AppTextStyles.bodySmall),
                const SizedBox(height: 3),
                Text(
                  '${announcement.createdByName} · '
                  '${RelativeTimeFormatter.agoFor(l10n, announcement.createdAt)}'
                  '${announcement.isExpired ? l10n.announcementsExpiredSuffix : ''}',
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 11.5,
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: l10n.announcementsEndTooltip,
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(l10n.announcementsEndTitle),
                  content: Text(l10n.announcementsEndMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(l10n.commonCancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(l10n.announcementsEndConfirm),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await deleteAnnouncement(
                  ref,
                  announcement.id,
                  propertyId: propertyId,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _AnnouncementsSkeleton extends StatelessWidget {
  const _AnnouncementsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonBox(width: double.infinity, height: 56),
        SizedBox(height: AppSpacing.space4),
        SkeletonBox(width: double.infinity, height: 80),
      ],
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonBox(width: double.infinity, height: 90),
        SizedBox(height: AppSpacing.space2),
        SkeletonBox(width: double.infinity, height: 90),
      ],
    );
  }
}
