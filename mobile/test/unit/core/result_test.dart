import 'package:flutter_test/flutter_test.dart';
import 'package:pg_khata/core/errors/app_failure.dart';
import 'package:pg_khata/core/errors/result.dart';

void main() {
  group('Result', () {
    test('Ok.when calls the ok branch with the value', () {
      const result = Ok<int>(42);
      final matched = result.when(
        ok: (value) => 'value: $value',
        err: (_) => 'failure',
      );
      expect(matched, 'value: 42');
    });

    test('Err.when calls the err branch with the failure', () {
      const result = Err<int>(UnexpectedFailure());
      final matched = result.when(
        ok: (_) => 'value',
        err: (failure) => failure.message,
      );
      expect(matched, const UnexpectedFailure().message);
    });

    test('isOk reflects the variant', () {
      expect(const Ok<int>(1).isOk, isTrue);
      expect(const Err<int>(UnexpectedFailure()).isOk, isFalse);
    });
  });
}
