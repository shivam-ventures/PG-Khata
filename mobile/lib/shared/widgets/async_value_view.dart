import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import 'error_state.dart';

/// Renders an [AsyncValue] as loading/error/data, so the three dashboard
/// screens (and anything built later against a Riverpod provider) don't each
/// re-implement the same `when(...)` boilerplate.
///
/// [loading] is required rather than defaulted to a spinner, per the design
/// rule that a data-heavy screen shows a skeleton shaped like its real
/// content — callers should pass their screen's own skeleton layout.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    required this.loading,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) data;
  final WidgetBuilder loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (value) => data(context, value),
      loading: () => loading(context),
      error: (error, _) => ErrorState(
        message: error is AppFailure ? error.message : _friendlyMessage,
        onRetry: onRetry,
      ),
    );
  }

  static const _friendlyMessage = 'Something went wrong loading this screen.';
}
