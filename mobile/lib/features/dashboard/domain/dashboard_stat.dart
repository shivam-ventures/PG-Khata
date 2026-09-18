import 'package:flutter/widgets.dart';

import '../../../shared/widgets/semantic_tone.dart';

/// One tile in a stat grid/row — the `stats` shape shared by the Owner
/// Dashboard's stat grid and the Manager Today mini-stat row.
class DashboardStat {
  const DashboardStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final SemanticTone tone;
}
