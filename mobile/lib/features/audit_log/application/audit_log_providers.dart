import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/audit_log_repository.dart';
import '../data/supabase_audit_log_repository.dart';
import '../domain/audit_log_entry.dart';

final auditLogRepositoryProvider = Provider<AuditLogRepository>(
  (ref) => SupabaseAuditLogRepository(ref.watch(supabaseClientProvider)),
);

final auditLogProvider = FutureProvider<List<AuditLogEntry>>((ref) async {
  final result = await ref.watch(auditLogRepositoryProvider).fetchAuditLog();
  return result.when(ok: (v) => v, err: (failure) => throw failure);
});
