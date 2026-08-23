import 'package:flutter_test/flutter_test.dart';
import 'package:studysync/core/security/password_hasher.dart';

void main() {
  // Low iteration count keeps the suite fast; the algorithm under test is
  // identical either way.
  const hasher = PasswordHasher(iterations: 1000);

  group('PasswordHasher', () {
    test('verifies a password against its own digest', () async {
      final encoded = await hasher.hash('correct horse battery staple');

      expect(
        await hasher.verify('correct horse battery staple', encoded),
        isTrue,
      );
    });

    test('rejects a wrong password', () async {
      final encoded = await hasher.hash('correct horse battery staple');

      expect(await hasher.verify('Correct horse battery staple', encoded),
          isFalse);
      expect(await hasher.verify('', encoded), isFalse);
    });

    test('produces a different digest each time for the same password',
        () async {
      final first = await hasher.hash('same-password-123');
      final second = await hasher.hash('same-password-123');

      // Different random salt means identical passwords cannot be spotted by
      // comparing stored digests.
      expect(first, isNot(equals(second)));
      expect(await hasher.verify('same-password-123', first), isTrue);
      expect(await hasher.verify('same-password-123', second), isTrue);
    });

    test('encodes algorithm, iterations, salt and digest', () async {
      final encoded = await hasher.hash('another-password-1');
      final parts = encoded.split(r'$');

      expect(parts, hasLength(4));
      expect(parts[0], 'pbkdf2_sha256');
      expect(parts[1], '1000');

      final decoded = PasswordHash.decode(encoded);
      expect(decoded.iterations, 1000);
      expect(decoded.salt, hasLength(16));
      expect(decoded.hash, hasLength(32));
    });

    test('flags digests created with weaker parameters for rehashing',
        () async {
      final weak = await const PasswordHasher(iterations: 500).hash('pw-123456');

      expect(hasher.needsRehash(weak), isTrue);
      expect(hasher.needsRehash(await hasher.hash('pw-123456')), isFalse);
    });

    test('treats an unparseable digest as a failed verification', () async {
      expect(await hasher.verify('anything', 'not-a-real-hash'), isFalse);
      expect(hasher.needsRehash('not-a-real-hash'), isTrue);
    });

    test('constant-time comparison still returns the correct answer', () {
      expect(
        PasswordHasher.constantTimeEquals(<int>[1, 2, 3], <int>[1, 2, 3]),
        isTrue,
      );
      expect(
        PasswordHasher.constantTimeEquals(<int>[1, 2, 3], <int>[1, 2, 4]),
        isFalse,
      );
      expect(
        PasswordHasher.constantTimeEquals(<int>[1, 2], <int>[1, 2, 3]),
        isFalse,
      );
    });

    test('generates salts of the requested length that differ each call', () {
      final first = PasswordHasher.generateSalt();
      final second = PasswordHasher.generateSalt();

      expect(first, hasLength(16));
      expect(first, isNot(equals(second)));
    });
  });
}
