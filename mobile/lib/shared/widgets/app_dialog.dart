import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// The app's one modal surface (`.dialog` in the design) — a title, body
/// content, and a right-aligned action row. Used instead of a separate page
/// wherever the design shows a form/info dialog rather than navigation.
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.content,
    required this.actions,
    super.key,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (_) =>
          AppDialog(title: title, content: content, actions: actions),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
      ),
      content: content,
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        0,
        AppSpacing.space4,
        AppSpacing.space4,
      ),
      actions: actions,
    );
  }
}
