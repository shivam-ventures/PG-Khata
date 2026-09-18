import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/errors/app_failure.dart';
import 'package:pg_khata/core/errors/result.dart';
import 'package:pg_khata/features/auth/data/mock_auth_repository.dart';
import 'package:pg_khata/features/auth/domain/user_role.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  group('MockAuthRepository.sendOtp', () {
    test('always succeeds', () async {
      final result = await repository.sendOtp('9876543210');
      expect(result.isOk, isTrue);
    });
  });

  group('MockAuthRepository.verifyOtp', () {
    test('resolves a seeded demo phone to its role', () async {
      final result = await repository.verifyOtp(
        phoneNumber: '9876543210',
        otp: '123456',
      );
      final user = result.when(ok: (user) => user, err: (_) => null);
      expect(user, isNotNull);
      expect(user!.role, UserRole.owner);
      expect(user.name, 'Anita Sharma');
    });

    test('resolves each seeded demo account to the documented role', () async {
      final manager = await repository.verifyOtp(
        phoneNumber: '9876500000',
        otp: '123456',
      );
      final tenant = await repository.verifyOtp(
        phoneNumber: '9000000001',
        otp: '123456',
      );

      expect(
        manager.when(ok: (u) => u.role, err: (_) => null),
        UserRole.manager,
      );
      expect(tenant.when(ok: (u) => u.role, err: (_) => null), UserRole.tenant);
    });

    test('an unrecognized phone still signs in, as a new tenant', () async {
      final result = await repository.verifyOtp(
        phoneNumber: '9999999999',
        otp: '123456',
      );
      final user = result.when(ok: (user) => user, err: (_) => null);
      expect(user, isNotNull);
      expect(user!.role, UserRole.tenant);
    });

    test('a wrong code fails with InvalidOtpFailure', () async {
      final result = await repository.verifyOtp(
        phoneNumber: '9876543210',
        otp: '000000',
      );
      final failure = result.when(ok: (_) => null, err: (failure) => failure);
      expect(failure, isA<InvalidOtpFailure>());
    });
  });
}
