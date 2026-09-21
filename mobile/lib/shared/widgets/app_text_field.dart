import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's one text-input style (`.input` in the design) — wraps
/// [TextField] so every field gets the same label placement and a consistent
/// place to add semantics/error text, per the accessibility requirement that
/// every input has a meaningful, readable label.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.errorText,
    this.autofocus = false,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final bool autofocus;
  final int? maxLength;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autofocus: autofocus,
      maxLength: maxLength,
      maxLines: maxLines,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        counterText: '',
      ),
    );
  }
}
