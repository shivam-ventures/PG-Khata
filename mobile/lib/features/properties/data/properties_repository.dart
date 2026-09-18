import '../../../core/errors/result.dart';
import '../domain/property.dart';

/// Owner-portfolio CRUD. [MockPropertiesRepository] backs this in Phase 0/1;
/// a Supabase-backed implementation replaces it in Phase 6 behind the same
/// interface.
abstract interface class PropertiesRepository {
  Future<Result<List<Property>>> fetchProperties();

  Future<Result<Property>> addProperty({
    required String name,
    required String address,
    required int totalBeds,
    required String managerName,
  });

  Future<Result<Property>> updateProperty(
    String id, {
    required String name,
    required String address,
    required int totalBeds,
    required String managerName,
  });
}
