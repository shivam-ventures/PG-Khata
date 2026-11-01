import '../../../core/errors/result.dart';
import '../domain/org_manager.dart';
import '../domain/property.dart';

/// Owner-portfolio CRUD, plus manager assignment. [MockPropertiesRepository]
/// backs this for isolated UI dev/tests; [SupabasePropertiesRepository] is
/// the real backend.
abstract interface class PropertiesRepository {
  Future<Result<List<Property>>> fetchProperties();

  Future<Result<Property>> addProperty({
    required String name,
    required String address,
    required int totalBeds,
  });

  Future<Result<Property>> updateProperty(
    String id, {
    required String name,
    required String address,
    required int totalBeds,
  });

  /// Every manager already active somewhere in the Owner's org — the pool
  /// to assign from without creating a duplicate account.
  Future<Result<List<OrgManager>>> fetchOrgManagers();

  /// Assigns an already-active manager to [propertyId], unassigning
  /// whoever is there now (this app's UI only ever shows one manager per
  /// property, even though the schema allows more).
  Future<Result<void>> assignExistingManager(String propertyId, String managerId);

  /// Creates a brand-new manager account (or reuses one that already
  /// exists for this phone) and assigns them to [propertyId], unassigning
  /// whoever is there now.
  Future<Result<void>> inviteAndAssignManager(
    String propertyId, {
    required String name,
    required String phone,
  });

  Future<Result<void>> unassignManager(String propertyId, String managerId);
}
