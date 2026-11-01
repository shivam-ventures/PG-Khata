import '../../../l10n/app_localizations.dart';

/// A room's sharing type, which fixes its bed count — matches the design's
/// Add Room form exactly (`Owner Rooms.dc.html`'s `BEDS_PER_SHARING` map).
enum SharingType {
  single,
  double_,
  triple,
  four;

  /// Unlocalized — kept only for call sites not yet migrated. Prefer
  /// [labelFor].
  String get label => switch (this) {
    SharingType.single => 'Single',
    SharingType.double_ => 'Double sharing',
    SharingType.triple => 'Triple sharing',
    SharingType.four => 'Four sharing',
  };

  String labelFor(AppLocalizations l10n) => switch (this) {
    SharingType.single => l10n.roomSharingSingle,
    SharingType.double_ => l10n.roomSharingDouble,
    SharingType.triple => l10n.roomSharingTriple,
    SharingType.four => l10n.roomSharingFour,
  };

  int get bedCount => switch (this) {
    SharingType.single => 1,
    SharingType.double_ => 2,
    SharingType.triple => 3,
    SharingType.four => 4,
  };
}
