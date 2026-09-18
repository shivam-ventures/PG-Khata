import 'app_failure.dart';

/// The outcome of a repository call: either a value ([Ok]) or a typed
/// [AppFailure] ([Err]) — never a thrown exception the UI has to guess about.
///
/// Repositories return `Future<Result<T>>` rather than `Future<T>` so every
/// call site is forced to handle failure explicitly instead of relying on
/// try/catch scattered through the UI layer.
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;
}

extension ResultX<T> on Result<T> {
  bool get isOk => this is Ok<T>;

  /// Pattern-matches this result into a single value of type [R].
  R when<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) err,
  }) {
    final self = this;
    return switch (self) {
      Ok<T>() => ok(self.value),
      Err<T>() => err(self.failure),
    };
  }
}
