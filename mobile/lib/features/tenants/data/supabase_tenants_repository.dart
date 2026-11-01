import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/deposit_settlement.dart';
import '../domain/tenant_record.dart';
import '../domain/tenant_status.dart';
import 'tenants_repository.dart';

/// Real backend for [TenantsRepository]. A tenancy row carries no name,
/// phone, property or room/bed text of its own — those come from joining
/// `beds`→`rooms`→`properties` and `profiles`, resolved client-side into
/// the flat [TenantRecord] shape the UI already expects.
///
/// [addTenant] can't insert a tenancy directly: the person being added may
/// have never opened the app, so there's no `auth.users`/`profiles` row to
/// attach it to yet — that needs the Admin API, which only the `add-tenant`
/// Edge Function (service role) can call. Every other write here is a plain
/// RPC (`docs/backend-domain-model.md` §11's authorization-in-function
/// pattern).
class SupabaseTenantsRepository implements TenantsRepository {
  SupabaseTenantsRepository(this._client);

  final SupabaseClient _client;

  // `tenancies` has two FKs to `profiles` (profile_id, created_by), so the
  // embed must name which one — see the same PGRST201 ambiguity hit while
  // wiring Properties' manager-name join.
  static const _selectColumns =
      'id, rent_amount, move_in_date, status, security_deposit_amount, '
      'move_out_date, notice_given_at, deposit_settlement, '
      'beds!inner(label, rooms!inner(room_number, property_id, '
      'properties!inner(id, name))), '
      'tenant:profiles!tenancies_profile_id_fkey(full_name, phone)';

  @override
  Future<Result<List<TenantRecord>>> fetchTenants({String? propertyId}) async {
    // A blank id shows up briefly for a Manager whose real assigned
    // property hasn't loaded yet (see managerSelectedPgIdProvider) — treat
    // it as "nothing to show" rather than sending an empty string where
    // Postgres expects a uuid, which would fail the cast.
    if (propertyId == '') return const Ok([]);
    try {
      final builder = _client.from('tenancies').select(_selectColumns);
      final scoped = propertyId == null
          ? builder
          : builder.eq('beds.rooms.property_id', propertyId);
      final rows = await scoped.order('created_at');
      return Ok([for (final row in rows) _toTenantRecord(row)]);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  static const _pendingSelectColumns =
      'id, property_id, properties!inner(name), '
      'profile:profiles!tenant_signup_interests_profile_id_fkey(full_name, phone)';

  @override
  Future<Result<List<PendingTenant>>> fetchPendingTenants({
    String? propertyId,
  }) async {
    if (propertyId == '') return const Ok([]);
    try {
      final builder = _client
          .from('tenant_signup_interests')
          .select(_pendingSelectColumns);
      final scoped = propertyId == null
          ? builder
          : builder.eq('property_id', propertyId);
      final rows = await scoped.order('created_at');
      return Ok([
        for (final row in rows)
          PendingTenant(
            id: row['id'] as String,
            name: (row['profile'] as Map<String, dynamic>)['full_name']
                as String,
            phone: (row['profile'] as Map<String, dynamic>)['phone']
                as String,
            propertyId: row['property_id'] as String,
            propertyName: (row['properties'] as Map<String, dynamic>)['name']
                as String,
          ),
      ]);
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<TenantRecord>> addTenant({
    required String name,
    required String phone,
    required String propertyId,
    required String propertyName,
    required String roomBed,
    required int rent,
    required DateTime joinedDate,
    required TenantStatus status,
    int? depositAmount,
  }) async {
    try {
      final bedId = await _resolveBedId(propertyId, roomBed);
      if (bedId == null) return const Err(BedNotFoundFailure());

      final response = await _client.functions.invoke(
        'add-tenant',
        body: {
          'name': name,
          'phone': _bareDigits(phone),
          'bedId': bedId,
          'rentAmount': rent,
          if (depositAmount != null) 'depositAmount': depositAmount,
          'moveInDate': _isoDate(joinedDate),
        },
      );
      final data = response.data as Map<String, dynamic>;
      final tenancy = data['tenancy'] as Map<String, dynamic>;
      // A freshly created tenancy is always 'active' — the real schema has
      // no way to back-date straight to notice-period/vacated the way the
      // mock's Status dropdown pretends to, so [status] is accepted for
      // interface compatibility but intentionally not used here.
      return Ok(
        TenantRecord(
          id: tenancy['id'] as String,
          name: name,
          phone: _bareDigits(phone),
          propertyId: propertyId,
          propertyName: propertyName,
          roomBed: roomBed,
          rent: rent,
          joinedDate: joinedDate,
          status: TenantStatus.active,
          depositAmount: depositAmount,
        ),
      );
    } on FunctionException catch (e) {
      if (e.status == 409) return const Err(BedAlreadyOccupiedFailure());
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<TenantRecord>> assignPendingTenant(
    String pendingId, {
    required String roomBed,
    required int rent,
    required DateTime joinedDate,
    int? depositAmount,
  }) async {
    try {
      final interest = await _client
          .from('tenant_signup_interests')
          .select('property_id')
          .eq('id', pendingId)
          .single();
      final propertyId = interest['property_id'] as String;

      final bedId = await _resolveBedId(propertyId, roomBed);
      if (bedId == null) return const Err(BedNotFoundFailure());

      final created = await _client.rpc(
        'assign_pending_tenant',
        params: {
          'p_interest_id': pendingId,
          'p_bed_id': bedId,
          'p_rent_amount': rent,
          if (depositAmount != null) 'p_deposit_amount': depositAmount,
          'p_move_in_date': _isoDate(joinedDate),
        },
      );
      final tenancyId = (created as Map<String, dynamic>)['id'] as String;
      final row = await _client
          .from('tenancies')
          .select(_selectColumns)
          .eq('id', tenancyId)
          .single();
      return Ok(_toTenantRecord(row));
    } on PostgrestException catch (e) {
      // The partial unique index backing "one active tenancy per bed"
      // (docs/backend-domain-model.md §4) — same race the addTenant Edge
      // Function's 409 already covers for a staff-created tenant.
      if (e.code == '23505') return const Err(BedAlreadyOccupiedFailure());
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<TenantRecord>> moveOutTenant(String tenantId) async {
    try {
      await _client.rpc('move_out_tenant', params: {'p_tenancy_id': tenantId});
      final row = await _client
          .from('tenancies')
          .select(_selectColumns)
          .eq('id', tenantId)
          .single();
      return Ok(_toTenantRecord(row));
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<TenantRecord>> requestMoveOut(
    String tenantId, {
    required DateTime moveOutDate,
    bool acknowledgeForfeiture = false,
  }) async {
    try {
      await _client.rpc(
        'request_move_out',
        params: {
          'p_tenancy_id': tenantId,
          'p_move_out_date': _isoDate(moveOutDate),
          'p_acknowledge_forfeiture': acknowledgeForfeiture,
        },
      );
      final row = await _client
          .from('tenancies')
          .select(_selectColumns)
          .eq('id', tenantId)
          .single();
      return Ok(_toTenantRecord(row));
    } on PostgrestException catch (e) {
      if (e.message.contains('short_notice')) {
        // Parse both numbers out of the server's own rejection message
        // ("short_notice: only 10 days' notice given — 15 required, ...")
        // rather than recomputing them client-side — the backend
        // (minimum_notice_days(), migration 37) is the single source of
        // truth for the required threshold, so this can never disagree
        // with what it actually enforced, even if the policy changes.
        final match = RegExp(
          r'only (\d+) days.*?(\d+) required',
        ).firstMatch(e.message);
        final noticeDays = match != null
            ? int.parse(match.group(1)!)
            : moveOutDate.difference(DateTime.now()).inDays;
        final requiredDays = match != null ? int.parse(match.group(2)!) : 15;
        return Err(ShortNoticeFailure(noticeDays, requiredDays));
      }
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<TenantRecord>> cancelMoveOutNotice(String tenantId) async {
    try {
      await _client.rpc(
        'cancel_move_out_notice',
        params: {'p_tenancy_id': tenantId},
      );
      final row = await _client
          .from('tenancies')
          .select(_selectColumns)
          .eq('id', tenantId)
          .single();
      return Ok(_toTenantRecord(row));
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  @override
  Future<Result<TenantRecord>> markDepositReturned(String tenantId) async {
    try {
      await _client.rpc(
        'mark_deposit_returned',
        params: {'p_tenancy_id': tenantId},
      );
      final row = await _client
          .from('tenancies')
          .select(_selectColumns)
          .eq('id', tenantId)
          .single();
      return Ok(_toTenantRecord(row));
    } on PostgrestException {
      return const Err(UnexpectedFailure());
    } catch (_) {
      return const Err(UnexpectedFailure());
    }
  }

  /// Parses the UI's free-text "101 - B" room/bed field and resolves it to
  /// a real bed id, scoped to [propertyId] — the real schema has no other
  /// way to identify a bed from that display string.
  Future<String?> _resolveBedId(String propertyId, String roomBed) async {
    final parts = roomBed.split('-').map((s) => s.trim()).toList();
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return null;
    }
    final row = await _client
        .from('beds')
        .select('id, rooms!inner(room_number, property_id)')
        .eq('label', parts[1])
        .eq('rooms.room_number', parts[0])
        .eq('rooms.property_id', propertyId)
        .maybeSingle();
    return row?['id'] as String?;
  }

  TenantRecord _toTenantRecord(Map<String, dynamic> row) {
    final bed = row['beds'] as Map<String, dynamic>;
    final room = bed['rooms'] as Map<String, dynamic>;
    final property = room['properties'] as Map<String, dynamic>;
    final tenant = row['tenant'] as Map<String, dynamic>;
    final moveOutDate = row['move_out_date'] as String?;
    final noticeGivenAt = row['notice_given_at'] as String?;
    final depositSettlement = row['deposit_settlement'] as String?;
    return TenantRecord(
      id: row['id'] as String,
      name: tenant['full_name'] as String,
      phone: tenant['phone'] as String,
      propertyId: property['id'] as String,
      propertyName: property['name'] as String,
      roomBed: '${room['room_number']} - ${bed['label']}',
      rent: (row['rent_amount'] as num).round(),
      joinedDate: DateTime.parse(row['move_in_date'] as String),
      status: _statusFromDb(row['status'] as String),
      depositAmount: (row['security_deposit_amount'] as num?)?.round(),
      moveOutDate: moveOutDate == null ? null : DateTime.parse(moveOutDate),
      noticeGivenAt: noticeGivenAt == null
          ? null
          : DateTime.parse(noticeGivenAt),
      depositSettlement: _depositSettlementFromDb(depositSettlement),
    );
  }

  DepositSettlement? _depositSettlementFromDb(String? value) => switch (value) {
    null => null,
    'pending' => DepositSettlement.pending,
    'forfeited' => DepositSettlement.forfeited,
    'returned' => DepositSettlement.returned,
    _ => throw StateError('Unknown deposit_settlement from database: $value'),
  };

  TenantStatus _statusFromDb(String value) => switch (value) {
    'active' => TenantStatus.active,
    'notice_period' => TenantStatus.noticePeriod,
    'moved_out' => TenantStatus.vacated,
    _ => throw StateError('Unknown tenancy status from database: $value'),
  };

  String _bareDigits(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
