import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// A block shaped like real content, for a loading state — per the design
/// system's rule that a data-heavy screen shows a skeleton of its own layout
/// rather than a bare spinner.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = AppRadius.smAll,
    super.key,
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceAlt,
        borderRadius: borderRadius,
      ),
    );
  }
}

/// A full-width skeleton line, for a heading or a row of text.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({this.width, this.height = 14, super.key});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SkeletonBox(
        width: width ?? double.infinity,
        height: height,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}
