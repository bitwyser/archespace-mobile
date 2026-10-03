import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Dart port of the ArcheSpace `arc1` crypto contract.
///
/// Must stay byte-compatible with the web reference implementation so data
/// encrypted on either client decrypts on the other. Validated against
/// `spec/vectors.json` by `test/crypto_vectors_test.dart`. See
/// `spec/crypto-format.md` for the full contract.
class ArcheCrypto {
  ArcheCrypto._();

  static const _prefix = 'arc1:';
  static const _tagLength = 16; // AES-GCM 128-bit auth tag
  static final AesGcm _aes = AesGcm.with256bits(nonceLength: 12);

  // Argon2id parameters, matching the web (OWASP-aligned): 19 MiB, 2 passes,
  // 1 lane.
  static const _argonMemory = 19456; // KiB
  static const _argonIterations = 2;
  static const _argonParallelism = 1;

  // PBKDF2-SHA-256 iterations that pre-Argon2id vaults were made with.
  static const _legacyPbkdf2Iterations = 310000;

  /// Whether a stored salt predates Argon2id (a plain base64 PBKDF2 salt).
  static bool isLegacySaltDescriptor(String descriptor) =>
      !descriptor.startsWith('argon2id\$');

  /// Generate a fresh random 32-byte AES-256 master key. Equivalent to the
  /// web's `crypto.subtle.generateKey` + raw export.
  static Uint8List randomAesKey() {
    final rng = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256)));
  }

  /// Build a self-describing salt descriptor for a NEW wrapping key, matching
  /// the web `newSaltDescriptor()`: `argon2id$<m>$<t>$<p>$<saltB64>` with a
  /// fresh 16-byte random salt. [deriveVaultKey] reads the params back out.
  static String newSaltDescriptor() {
    final rng = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => rng.nextInt(256)),
    );
    return 'argon2id\$$_argonMemory\$$_argonIterations\$$_argonParallelism\$${base64.encode(salt)}';
  }

  /// Derive the 32-byte AES key from a vault secret using the Argon2id
  /// parameters in [descriptor] (`argon2id$m$t$p$saltB64`). A vault made
  /// before Argon2id stores a plain base64 salt for PBKDF2; it still opens,
  /// and unlock moves it to Argon2id (see VaultService).
  static Future<Uint8List> deriveVaultKey(
    String secret,
    String descriptor,
  ) async {
    if (isLegacySaltDescriptor(descriptor)) {
      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _legacyPbkdf2Iterations,
        bits: 256,
      );
      final key = await pbkdf2.deriveKey(
        secretKey: SecretKey(utf8.encode(secret)),
        nonce: base64.decode(descriptor),
      );
      return Uint8List.fromList(await key.extractBytes());
    }
    final parts = descriptor.split('\$'); // [argon2id, m, t, p, saltB64]
    if (parts.length != 5) {
      throw const FormatException('Unsupported vault key format.');
    }
    final algorithm = Argon2id(
      memory: int.parse(parts[1]), // KiB
      iterations: int.parse(parts[2]),
      parallelism: int.parse(parts[3]),
      hashLength: 32,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: base64.decode(parts[4]),
    );
    return Uint8List.fromList(await key.extractBytes());
  }

  /// Decrypt an `arc1:` value with a raw 32-byte AES key. An empty value
  /// decrypts to ''; anything else that isn't `arc1:` is rejected.
  static Future<String> decryptArc1(String value, List<int> keyBytes) async {
    if (value.isEmpty) return '';
    if (!value.startsWith(_prefix)) {
      throw const FormatException('Not an encrypted value');
    }
    final body = value.substring(_prefix.length);
    final dot = body.indexOf('.');
    if (dot < 0) throw const FormatException('Invalid arc1 payload');

    final iv = base64.decode(body.substring(0, dot));
    final ctWithTag = base64.decode(body.substring(dot + 1));
    // The web appends the GCM tag to the ciphertext; split it back out.
    final cipherText = ctWithTag.sublist(0, ctWithTag.length - _tagLength);
    final mac = Mac(ctWithTag.sublist(ctWithTag.length - _tagLength));

    final clear = await _aes.decrypt(
      SecretBox(cipherText, nonce: iv, mac: mac),
      secretKey: SecretKey(keyBytes),
    );
    return utf8.decode(clear);
  }

  /// Decrypt an encrypted JSON object (an item's content); `{}` when empty.
  static Future<Map<String, dynamic>> decryptJsonMap(
    Object? value,
    List<int> keyBytes,
  ) async {
    if (value is! String || value.isEmpty) return <String, dynamic>{};
    final text = await decryptArc1(value, keyBytes);
    if (text.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(text);
    return decoded is Map
        ? decoded.cast<String, dynamic>()
        : <String, dynamic>{};
  }

  /// Decrypt a row's tags. Tags left at the column default (an empty list)
  /// were never encrypted.
  static Future<List<String>> decryptTags(
    Object? value,
    List<int> keyBytes,
  ) async {
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is! String || value.isEmpty) return const [];
    final text = await decryptArc1(value, keyBytes);
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return const [];
  }

  /// Encrypt a string into an `arc1:` value (fresh random 12-byte IV).
  static Future<String> encryptArc1(
    String plaintext,
    List<int> keyBytes,
  ) async {
    final box = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(keyBytes),
    );
    final ctWithTag = <int>[...box.cipherText, ...box.mac.bytes];
    return '$_prefix${base64.encode(box.nonce)}.${base64.encode(ctWithTag)}';
  }
}
