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

/// The OTP was correct in shape but has expired — distinct from
/// [InvalidOtpFailure] (a wrong code) so the message tells the user to
/// request a new one rather than retype the same expired one.
final class OtpExpiredFailure extends AppFailure {
  const OtpExpiredFailure()
    : super('That code has expired. Request a new one and try again.');
}

/// Too many OTP requests/attempts in a short window (Supabase Auth's own
/// rate limiting) — distinct from a plain network failure so support isn't
/// chasing a phantom connectivity issue, and the user knows to wait rather
/// than keep retrying immediately.
final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure()
    : super("Too many attempts. Please wait a bit before trying again.");
}

final class RoomNumberTakenFailure extends AppFailure {
  const RoomNumberTakenFailure()
    : super('A room with this number already exists in this PG.');
}

final class AccountNotFoundFailure extends AppFailure {
  const AccountNotFoundFailure()
    : super(
        "We couldn't find an account for this number. Ask your "
        "property owner or manager for an invite link.",
      );
}

final class InviteNotFoundFailure extends AppFailure {
  const InviteNotFoundFailure()
    : super("This invite link isn't valid. Ask your manager for a new one.");
}

final class InviteAlreadyUsedFailure extends AppFailure {
  const InviteAlreadyUsedFailure()
    : super('This invite link has already been used.');
}

final class InviteExpiredFailure extends AppFailure {
  const InviteExpiredFailure()
    : super('This invite link has expired. Ask your manager for a new one.');
}

final class BedNotFoundFailure extends AppFailure {
  const BedNotFoundFailure()
    : super("Couldn't find that room/bed in this PG. Check it and try again.");
}

final class BedAlreadyOccupiedFailure extends AppFailure {
  const BedAlreadyOccupiedFailure()
    : super('That bed was just taken by someone else. Pick another one.');
}

/// A move-out was requested with fewer than the required days' notice and
/// without acknowledging the deposit forfeiture — the UI should catch this
/// specifically and offer the "proceed anyway, forfeit the deposit" path
/// rather than just showing [message] as a dead end.
///
/// [noticeDays] and [requiredDays] come from the backend's own rejection
/// (`request_move_out`, driven by `minimum_notice_days()` — backend
/// migration 37) rather than a client-side constant, so this can never
/// state a stale threshold if the policy changes server-side.
final class ShortNoticeFailure extends AppFailure {
  ShortNoticeFailure(this.noticeDays, this.requiredDays)
    : super(
        "Only $noticeDays day${noticeDays == 1 ? '' : 's'}' notice — "
        '$requiredDays days are required, or the security deposit will be '
        'forfeited.',
      );

  final int noticeDays;
  final int requiredDays;
}

/// A tenant's self-payment amount didn't exactly match what's still owed on
/// the rent period (see `record_self_payment`, backend migration 34) — the
/// period may have just been partially paid by someone else, or is already
/// fully settled, since the screen last loaded.
final class PaymentAmountMismatchFailure extends AppFailure {
  const PaymentAmountMismatchFailure()
    : super(
        "That amount doesn't match what's currently owed — it may have "
        'just changed. Pull to refresh and try again.',
      );
}
