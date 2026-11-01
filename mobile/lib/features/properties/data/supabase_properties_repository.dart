import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/org_manager.dart';
import '../domain/property.dart';
import 'properties_repository.dart';

/// Real backend for [PropertiesRepository]. Row visibility is entirely
/// RLS-driven: the same `select` returns an Owner's whole org portfolio or
/// a Manager's assigned properties only, depending on who's signed in — see
/// `supabase/migrations/20260922000012_rls.sql`.
///
/// Manager assignment is a real `property_managers` join to an actual
/// account, not a name string — [assignExistingManager] and
/// [inviteAndAssignManager] cover the two real paths (someone already has
/// a manager account somewhere in this org, or they don't yet, which needs
/// the `add-manager` Edge Function's Admin API access).
class SupabasePropertiesRepository implements PropertiesRepository {
  SupabasePropertiesRepository(this._client);

  final SupabaseClient _client;

  // `property_managers` has two FKs to `profiles` (manager_user_id and
  // assigned_by), so the embed must name which one to disambiguate —
  // otherwise PostgREST rejects the query with PGRST201.
  static const _selectColumns =
      'id, name, address, total_beds, '
      'property_managers(unassigned_at, manager_user_id, '
      'manager:profiles!property_managers_manager_user_id_fkey(full_name))';

  @override
  Future<Result<List<Property>>> fetchProperties() async {
    try {
      final rows = await _client
          .from('properties')
          .select(_selectColumns)
          .filter('archived_at', 'is', null)
          .order('created_at');
      return Ok([for (final row in rows) _toProperty(row)]);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<Property>> addProperty({
    required String name,
    required String address,
    required int totalBeds,
  }) async {
    try {
      final orgId = await _requireOwnOrgId();
      final row = await _client
          .from('properties')
          .insert({
            'org_id': orgId,
            'name': name,
            'address': address,
            'total_beds': totalBeds,
          })
          .select(_selectColumns)
          .single();
      return Ok(_toProperty(row));
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<Property>> updateProperty(
    String id, {
    required String name,
    required String address,
    required int totalBeds,
  }) async {
    try {
      final row = await _client
          .from('properties')
          .update({'name': name, 'address': address, 'total_beds': totalBeds})
          .eq('id', id)
          .select(_selectColumns)
          .single();
      return Ok(_toProperty(row));
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<List<OrgManager>>> fetchOrgManagers() async {
    try {
      final rows = await _client
          .from('property_managers')
          .select(
            'manager:profiles!property_managers_manager_user_id_fkey(id, full_name, phone)',
          )
          .filter('unassigned_at', 'is', null);
      final byId = <String, OrgManager>{};
      for (final row in rows) {
        final manager = row['manager'] as Map<String, dynamic>?;
        if (manager == null) continue;
        final id = manager['id'] as String;
        byId[id] = OrgManager(
          id: id,
          name: manager['full_name'] as String,
          phone: manager['phone'] as String,
        );
      }
      return Ok(byId.values.toList());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> assignExistingManager(
    String propertyId,
    String managerId,
  ) async {
    try {
      await _client
          .from('property_managers')
          .update({'unassigned_at': DateTime.now().toIso8601String()})
          .eq('property_id', propertyId)
          .filter('unassigned_at', 'is', null);
      await _client.from('property_managers').insert({
        'property_id': propertyId,
        'manager_user_id': managerId,
        'assigned_by': _client.auth.currentUser?.id,
      });
      return const Ok(null);
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> inviteAndAssignManager(
    String propertyId, {
    required String name,
    required String phone,
  }) async {
    try {
      await _client.functions.invoke(
        'add-manager',
        body: {'name': name, 'phone': phone, 'propertyId': propertyId},
      );
      return const Ok(null);
    } on FunctionException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<void>> unassignManager(
    String propertyId,
    String managerId,
  ) async {
    try {
      await _client
          .from('property_managers')
          .update({'unassigned_at': DateTime.now().toIso8601String()})
          .eq('property_id', propertyId)
          .eq('manager_user_id', managerId)
          .filter('unassigned_at', 'is', null);
      return const Ok(null);
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  Future<String> _requireOwnOrgId() async {
    final userId = _client.auth.currentUser?.id;
    final row = await _client
        .from('organizations')
        .select('id')
        .eq('owner_user_id', userId as Object)
        .maybeSingle();
    if (row == null) {
      throw StateError('No organization found for the signed-in owner.');
    }
    return row['id'] as String;
  }

  Property _toProperty(Map<String, dynamic> row) {
    final assignments =
        ((row['property_managers'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .where((a) => a['unassigned_at'] == null)
            .toList();
    final activeNames = assignments
        .map((a) => (a['manager'] as Map?)?['full_name'] as String?)
        .whereType<String>()
        .toList();
    return Property(
      id: row['id'] as String,
      name: row['name'] as String,
      address: row['address'] as String,
      totalBeds: row['total_beds'] as int,
      managerName: activeNames.isEmpty ? 'Unassigned' : activeNames.join(', '),
      // The picker only supports a single manager per property even
      // though the schema allows more — first active assignment wins.
      managerId: assignments.isEmpty
          ? null
          : assignments.first['manager_user_id'] as String,
    );
  }
}
