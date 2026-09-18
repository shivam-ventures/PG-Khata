import 'package:flutter/material.dart';

/// The app's secondary-action button (`.btn-secondary` in the design) — used
/// for a screen's non-primary action, per the design rule of one primary
/// action per screen.
///
/// See [PrimaryButton]'s doc comment for why `expand: false` matters when
/// this sits in a `Row` instead of being the sole child of a `Column`.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
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
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: expand
          ? null
          : OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
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
