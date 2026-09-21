import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/errors/app_failure.dart';
import 'package:pg_khata/core/errors/result.dart';
import 'package:pg_khata/features/onboarding/data/mock_onboarding_repository.dart';

void main() {
  late MockOnboardingRepository repository;

  setUp(() => repository = MockOnboardingRepository());

  group('resolveInvite', () {
    test('resolves a seeded vacant-bed token', () async {
      final result = await repository.resolveInvite('hsr-101-C');
      final invite = result.when(ok: (i) => i, err: (_) => null);
      expect(invite, isNotNull);
      expect(invite!.propertyName, 'HSR PG');
      expect(invite.room, '101');
      expect(invite.bed, 'C');
    });

    test('an unknown token fails with InviteNotFoundFailure', () async {
      final result = await repository.resolveInvite('not-a-real-token');
      final failure = result.when(ok: (_) => null, err: (f) => f);
      expect(failure, isA<InviteNotFoundFailure>());
    });

    test('a consumed token fails with InviteAlreadyUsedFailure', () async {
      await repository.consumeInvite('hsr-101-C');
      final result = await repository.resolveInvite('hsr-101-C');
      final failure = result.when(ok: (_) => null, err: (f) => f);
      expect(failure, isA<InviteAlreadyUsedFailure>());
    });
  });

  group('verifyOtp', () {
    test('the mock code succeeds', () async {
      final result = await repository.verifyOtp(
        phoneNumber: '9998887770',
        otp: '123456',
      );
      expect(result, isA<Ok<void>>());
    });

    test('a wrong code fails with InvalidOtpFailure', () async {
      final result = await repository.verifyOtp(
        phoneNumber: '9998887770',
        otp: '000000',
      );
      final failure = result.when(ok: (_) => null, err: (f) => f);
      expect(failure, isA<InvalidOtpFailure>());
    });
  });
}
