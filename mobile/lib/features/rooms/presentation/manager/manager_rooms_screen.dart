import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../dashboard/application/dashboard_providers.dart';
import '../../application/rooms_providers.dart';
import '../../domain/room.dart';
import '../widgets/invite_tenant_dialog.dart';
import '../widgets/room_card.dart';

enum _RoomFilter { all, vacant, occupied }

/// The Manager's room/bed occupancy screen for their current PG — a flat
/// list (no floor headers), matching `Manager Rooms.dc.html` exactly.
/// Rendered inside [RoleShell]: page content only.
class ManagerRoomsScreen extends ConsumerStatefulWidget {
  const ManagerRoomsScreen({super.key});

  @override
  ConsumerState<ManagerRoomsScreen> createState() => _ManagerRoomsScreenState();
}

class _ManagerRoomsScreenState extends ConsumerState<ManagerRoomsScreen> {
  final _searchController = TextEditingController();
  _RoomFilter _filter = _RoomFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propertyId = ref.watch(managerSelectedPgIdProvider);
    final floorsAsync = ref.watch(roomsProvider(propertyId));

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
            'Rooms',
            style: AppTextStyles.screenTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: AsyncValueView(
            value: floorsAsync,
            onRetry: () => ref.invalidate(roomsProvider(propertyId)),
            loading: (context) => const _RoomsSkeleton(),
            data: (context, floors) => _RoomsBody(
              propertyId: propertyId,
              floors: floors,
              searchController: _searchController,
              filter: _filter,
              onFilterChanged: (value) => setState(() => _filter = value),
              onSearchChanged: () => setState(() {}),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoomsBody extends StatelessWidget {
  const _RoomsBody({
    required this.propertyId,
    required this.floors,
    required this.searchController,
    required this.filter,
    required this.onFilterChanged,
    required this.onSearchChanged,
  });

  final String propertyId;
  final List<Floor> floors;
  final TextEditingController searchController;
  final _RoomFilter filter;
  final ValueChanged<_RoomFilter> onFilterChanged;
  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final allRooms = [for (final floor in floors) ...floor.rooms];
    final query = searchController.text.trim().toLowerCase();
    final filtered = allRooms.where((room) {
      final matchesFilter = switch (filter) {
        _RoomFilter.all => true,
        _RoomFilter.vacant => room.hasVacantBed,
        _RoomFilter.occupied => !room.hasVacantBed,
      };
      final matchesSearch =
          query.isEmpty ||
          room.number.toLowerCase().contains(query) ||
          room.beds.any(
            (bed) => bed.tenantName?.toLowerCase().contains(query) ?? false,
          );
      return matchesFilter && matchesSearch;
    }).toList();

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
            DropdownMenuItem(value: _RoomFilter.all, child: Text('All rooms')),
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
          '${filtered.length} of ${allRooms.length} rooms',
          style: AppTextStyles.bodySmall.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const SizedBox(height: AppSpacing.space4),
        if (filtered.isEmpty)
          const EmptyState(
            icon: Icons.search_off,
            title: 'No rooms match',
            message: 'Try a different search or filter.',
          )
        else
          for (final room in filtered)
            RoomCard(
              room: room,
              vacantBedAction: (bed) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => context.push(
                      '${AppRoute.managerTenants}?room=${room.number}&bed=${bed.label}',
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                    ),
                    child: const Text(
                      'Assign existing',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space3),
                  TextButton(
                    onPressed: () => showInviteTenantDialog(
                      context,
                      propertyId: propertyId,
                      room: room.number,
                      bed: bed.label,
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                    ),
                    child: const Text(
                      'Invite via link',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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

class _RoomsSkeleton extends StatelessWidget {
  const _RoomsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.space4),
      children: const [
        SkeletonBox(width: double.infinity, height: 44),
        SizedBox(height: AppSpacing.space4),
        SkeletonBox(width: double.infinity, height: 100),
        SizedBox(height: AppSpacing.space3),
        SkeletonBox(width: double.infinity, height: 100),
      ],
    );
  }
}
