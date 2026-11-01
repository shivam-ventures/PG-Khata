import 'package:flutter/foundation.dart';

/// One entry in the signed-out "pick a PG" picker for direct
/// self-registration — backed by the `public_property_listings` view,
/// which exposes only listing-safe columns with no RLS (a person hasn't
/// signed in yet at this point).
@immutable
class PublicPropertyListing {
  const PublicPropertyListing({
    required this.propertyId,
    required this.name,
    required this.address,
    required this.vacantBedCount,
  });

  final String propertyId;
  final String name;
  final String address;
  final int vacantBedCount;
}
