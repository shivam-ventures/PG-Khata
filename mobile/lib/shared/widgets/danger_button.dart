import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The app's destructive-action button — a confirm on a dialog that undoes
/// or removes something ("Move out", "Undo payment"). Two call sites used
/// to hand-roll this as a bare `FilledButton` with the same danger color
/// each time; this is that pattern named once.
///
/// See [PrimaryButton]'s doc comment for why `expand: false` matters when
/// this sits in a `Row` instead of being the sole child of a `Column`.
class DangerButton extends StatelessWidget {
  const DangerButton({
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
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: context.appColors.danger,
        minimumSize: expand ? const Size.fromHeight(48) : const Size(0, 44),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}
