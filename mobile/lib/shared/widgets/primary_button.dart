import 'package:flutter/material.dart';

/// The app's one primary-action button (`.btn-primary` in the design),
/// with a built-in loading spinner so async actions (send OTP, verify OTP)
/// don't need to hand-roll a disabled/spinner state per call site.
///
/// Defaults to full-width, matching most of its uses (form/dialog CTAs).
/// The theme's button style sets `minimumSize: Size.fromHeight(...)`, which
/// Flutter reads as an *infinite* minimum width — harmless standalone, but
/// it starves any sibling when the button sits in a `Row` instead of being
/// the sole child of a `Column`. Pass `expand: false` there so the button
/// sizes to its own label instead of claiming the whole row.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: expand
          ? null
          : ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : Text(label),
    );
  }
}
