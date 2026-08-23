import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Encoded as `pbkdf2_sha256$<iterations>$<saltB64>$<hashB64>` so the
/// iteration count can be raised later without invalidating stored passwords.
class PasswordHash {
  const PasswordHash({
    required this.iterations,
    required this.salt,
    required this.hash,
  });

  factory PasswordHash.decode(String encoded) {
    final parts = encoded.split(r'$');
    if (parts.length != 4 || parts[0] != _algorithm) {
      throw const FormatException('Unrecognised password hash format');
    }
    return PasswordHash(
      iterations: int.parse(parts[1]),
      salt: base64Decode(parts[2]),
      hash: base64Decode(parts[3]),
    );
  }

  static const String _algorithm = 'pbkdf2_sha256';

  final int iterations;
  final Uint8List salt;
  final Uint8List hash;

  String encode() =>
      '$_algorithm\$$iterations\$${base64Encode(salt)}\$${base64Encode(hash)}';
}

/// Password hashing with PBKDF2-HMAC-SHA256.
///
/// Plaintext passwords are never stored or logged; only the encoded digest
/// reaches the database. Hashing runs on a background isolate because the
/// iteration count is deliberately high enough to be noticeable on the UI
/// thread.
class PasswordHasher {
  const PasswordHasher({this.iterations = 150000, this.keyLength = 32});

  final int iterations;
  final int keyLength;

  static final Random _secureRandom = Random.secure();

  Future<String> hash(String password) async {
    final salt = generateSalt();
    final derived = await compute(
      _derive,
      _Pbkdf2Request(
        password: password,
        salt: salt,
        iterations: iterations,
        keyLength: keyLength,
      ),
    );
    return PasswordHash(
      iterations: iterations,
      salt: salt,
      hash: derived,
    ).encode();
  }

  /// Returns true when [password] matches [encodedHash].
  ///
  /// The digest comparison is constant time so a caller cannot learn how much
  /// of a guess was correct by measuring how long the check took.
  Future<bool> verify(String password, String encodedHash) async {
    final PasswordHash parsed;
    try {
      parsed = PasswordHash.decode(encodedHash);
    } on FormatException {
      return false;
    }
    final derived = await compute(
      _derive,
      _Pbkdf2Request(
        password: password,
        salt: parsed.salt,
        iterations: parsed.iterations,
        keyLength: parsed.hash.length,
      ),
    );
    return constantTimeEquals(derived, parsed.hash);
  }

  /// True when [encodedHash] was produced with weaker parameters than the ones
  /// currently configured, meaning it should be re-hashed on next sign-in.
  bool needsRehash(String encodedHash) {
    try {
      return PasswordHash.decode(encodedHash).iterations < iterations;
    } on FormatException {
      return true;
    }
  }

  static Uint8List generateSalt([int length = 16]) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytes;
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class _Pbkdf2Request {
  const _Pbkdf2Request({
    required this.password,
    required this.salt,
    required this.iterations,
    required this.keyLength,
  });

  final String password;
  final Uint8List salt;
  final int iterations;
  final int keyLength;
}

/// Top-level so it can be handed to [compute].
Uint8List _derive(_Pbkdf2Request request) {
  final hmac = Hmac(sha256, utf8.encode(request.password));
  final blockCount = (request.keyLength / 32).ceil();
  final output = BytesBuilder();

  for (var block = 1; block <= blockCount; block++) {
    final blockIndex = Uint8List(4)
      ..[0] = block >> 24 & 0xff
      ..[1] = block >> 16 & 0xff
      ..[2] = block >> 8 & 0xff
      ..[3] = block & 0xff;

    var u = Uint8List.fromList(
      hmac.convert(<int>[...request.salt, ...blockIndex]).bytes,
    );
    final accumulator = Uint8List.fromList(u);

    for (var i = 1; i < request.iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (var j = 0; j < accumulator.length; j++) {
        accumulator[j] ^= u[j];
      }
    }
    output.add(accumulator);
  }

  return Uint8List.fromList(output.toBytes().sublist(0, request.keyLength));
}
