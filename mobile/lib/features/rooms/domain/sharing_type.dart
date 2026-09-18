/// A room's sharing type, which fixes its bed count — matches the design's
/// Add Room form exactly (`Owner Rooms.dc.html`'s `BEDS_PER_SHARING` map).
enum SharingType {
  single,
  double_,
  triple,
  four;

  String get label => switch (this) {
    SharingType.single => 'Single',
    SharingType.double_ => 'Double sharing',
    SharingType.triple => 'Triple sharing',
    SharingType.four => 'Four sharing',
  };

  int get bedCount => switch (this) {
    SharingType.single => 1,
    SharingType.double_ => 2,
    SharingType.triple => 3,
    SharingType.four => 4,
  };
}
