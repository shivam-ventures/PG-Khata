/// A user-facing failure. Repository calls return one of these (via
/// [Result]) instead of letting a raw exception reach the UI — screens show
/// [message], never a stack trace or exception `toString()`.
sealed class AppFailure {
  const AppFailure(this.message);

  final String message;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure()
    : super('Could not connect. Check your connection and try again.');
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure()
    : super('Something went wrong on our end. Please try again.');
}

final class InvalidOtpFailure extends AppFailure {
  const InvalidOtpFailure()
    : super("That code doesn't look right. Please try again.");
}
