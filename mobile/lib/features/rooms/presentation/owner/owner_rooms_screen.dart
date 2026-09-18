import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../properties/application/properties_providers.dart';
import '../../../properties/domain/property.dart';
import '../../application/rooms_providers.dart';
import '../../domain/room.dart';
import '../widgets/add_room_dialog.dart';
import '../widgets/room_card.dart';

enum _RoomFilter { all, vacant, occupied }

/// The Owner's room/bed occupancy screen for one property, floor-grouped.
/// Mirrors `Owner Rooms.dc.html`. Reached by pushing on top of the Owner
/// shell (via a property's "Manage rooms & beds" link) — not a bottom-nav
/// tab, so this screen provides its own [AppScaffold] and back button.
class OwnerRoomsScreen extends ConsumerStatefulWidget {
  const OwnerRoomsScreen({this.initialPropertyId, super.key});

  final String? initialPropertyId;

  @override
  ConsumerState<OwnerRoomsScreen> createState() => _OwnerRoomsScreenState();
}

class _OwnerRoomsScreenState extends ConsumerState<OwnerRoomsScreen> {
  final _searchController = TextEditingController();
  _RoomFilter _filter = _RoomFilter.all;

  @override
  void initState() {
    super.initState();
    if (widget.initialPropertyId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(selectedPropertyIdProvider.notifier)
            .select(widget.initialPropertyId!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(propertiesProvider);
    final propertyId = ref.watch(selectedPropertyIdProvider);

    return AppScaffold(
      body: Column(
        children: [
          _Header(propertyId: propertyId, propertiesAsync: propertiesAsync),
          Expanded(
            child: AsyncValueView(
              value: propertiesAsync,
              loading: (context) => const _RoomsSkeleton(),
              data: (context, properties) => _RoomsBody(
                propertyId: propertyId,
                searchController: _searchController,
                filter: _filter,
                onFilterChanged: (value) => setState(() => _filter = value),
                onSearchChanged: () => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.propertyId, required this.propertiesAsync});

  final String propertyId;
  final AsyncValue<List<Property>> propertiesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final properties = propertiesAsync.value ?? const <Property>[];
    final matches = properties.where((p) => p.id == propertyId);
    final currentName = matches.isEmpty ? 'Rooms' : matches.first.name;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: context.appColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      currentName,
                      style: AppTextStyles.screenTitle.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Rooms & beds',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          if (properties.length > 1)
            DropdownButtonFormField<String>(
              initialValue: properties.any((p) => p.id == propertyId)
                  ? propertyId
                  : null,
              decoration: const InputDecoration(labelText: 'Property'),
              items: [
                for (final property in properties)
                  DropdownMenuItem(
                    value: property.id,
                    child: Text(property.name),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  ref.read(selectedPropertyIdProvider.notifier).select(value);
                }
              },
            ),
          const SizedBox(height: AppSpacing.space2),
          PrimaryButton(
            label: 'Add Room',
            onPressed: () {
              final floorNames =
                  ref
                      .read(roomsProvider(propertyId))
                      .value
                      ?.map((f) => f.name)
                      .toList() ??
                  const [];
              showAddRoomDialog(
                context,
                propertyId: propertyId,
                floorNames: floorNames,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RoomsBody extends ConsumerWidget {
  const _RoomsBody({
    required this.propertyId,
    required this.searchController,
    required this.filter,
    required this.onFilterChanged,
    required this.onSearchChanged,
  });

  final String propertyId;
  final TextEditingController searchController;
  final _RoomFilter filter;
  final ValueChanged<_RoomFilter> onFilterChanged;
  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floorsAsync = ref.watch(roomsProvider(propertyId));

    return AsyncValueView(
      value: floorsAsync,
      onRetry: () => ref.invalidate(roomsProvider(propertyId)),
      loading: (context) => const _RoomsSkeleton(),
      data: (context, floors) {
        final query = searchController.text.trim().toLowerCase();
        var totalRooms = 0;
        var matchedRooms = 0;
        final filteredFloors = <Floor>[];
        for (final floor in floors) {
          final rooms = floor.rooms.where((room) {
            totalRooms++;
            final matchesFilter = switch (filter) {
              _RoomFilter.all => true,
              _RoomFilter.vacant => room.hasVacantBed,
              _RoomFilter.occupied => !room.hasVacantBed,
            };
            final matchesSearch =
                query.isEmpty ||
                room.number.toLowerCase().contains(query) ||
                room.beds.any(
                  (bed) =>
                      bed.tenantName?.toLowerCase().contains(query) ?? false,
                );
            final keep = matchesFilter && matchesSearch;
            if (keep) matchedRooms++;
            return keep;
          }).toList();
          if (rooms.isNotEmpty) {
            filteredFloors.add(Floor(name: floor.name, rooms: rooms));
          }
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.space4),
          children: [
            AppTextField(
              label: 'Search room or tenant',
              controller: searchController,
              onChanged: (_) => onSearchChanged(),
            ),
            const SizedBox(height: AppSpacing.space2),
            DropdownButtonFormField<_RoomFilter>(
              initialValue: filter,
              decoration: const InputDecoration(labelText: 'Filter'),
              items: const [
                DropdownMenuItem(
                  value: _RoomFilter.all,
                  child: Text('All rooms'),
                ),
                DropdownMenuItem(
                  value: _RoomFilter.vacant,
                  child: Text('Has vacant bed'),
                ),
                DropdownMenuItem(
                  value: _RoomFilter.occupied,
                  child: Text('Fully occupied'),
                ),
              ],
              onChanged: (value) {
                if (value != null) onFilterChanged(value);
              },
            ),
            const SizedBox(height: AppSpacing.space1),
            Text(
              '$matchedRooms of $totalRooms rooms',
              style: AppTextStyles.bodySmall.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            if (matchedRooms == 0)
              const EmptyState(
                icon: Icons.search_off,
                title: 'No rooms match',
                message: 'Try a different search or filter.',
              )
            else
              for (final floor in filteredFloors) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space2),
                  child: Text(
                    floor.name,
                    style: AppTextStyles.sectionHeading.copyWith(fontSize: 16),
                  ),
                ),
                for (final room in floor.rooms)
                  RoomCard(
                    room: room,
                    vacantBedAction: (bed) => TextButton(
                      onPressed: () => context.go(AppRoute.ownerTenants),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                      ),
                      child: const Text(
                        '+ Add tenant',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.space2),
              ],
          ],
        );
      },
    );
  }
}

class _RoomsSkeleton extends StatelessWidget {
  const _RoomsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonBox(width: double.infinity, height: 44),
        SizedBox(height: AppSpacing.space4),
        SkeletonBox(width: double.infinity, height: 140),
        SizedBox(height: AppSpacing.space3),
        SkeletonBox(width: double.infinity, height: 140),
      ],
    );
  }
}
