/// RFC 6238 TOTP generation and otpauth:// parsing, ported from the web
/// `totp.js`. Codes are computed on-device; the secrets live in the item's
/// encrypted content, so they are stored zero-knowledge like any vault data.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// Decode a Base32 (RFC 4648) secret to bytes, ignoring spaces/padding/case.
Uint8List base32Decode(String input) {
  final clean = input
      .toUpperCase()
      .replaceAll(RegExp(r'=+$'), '')
      .replaceAll(RegExp(r'\s+'), '');
  var bits = 0;
  var value = 0;
  final out = <int>[];
  for (final ch in clean.split('')) {
    final idx = _base32Alphabet.indexOf(ch);
    if (idx == -1) continue; // skip stray separators
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      out.add((value >> bits) & 0xff);
    }
  }
  return Uint8List.fromList(out);
}

/// True when a string decodes to a usable Base32 secret.
bool isValidTotpSecret(String secret) => base32Decode(secret).isNotEmpty;

MacAlgorithm _macFor(String algorithm) {
  switch (algorithm.toUpperCase()) {
    case 'SHA256':
      return Hmac.sha256();
    case 'SHA512':
      return Hmac.sha512();
    default:
      return Hmac.sha1();
  }
}

/// Generate a TOTP code, or null if the secret is empty/invalid.
Future<String?> generateTotp(
  String secretBase32, {
  int digits = 6,
  int period = 30,
  String algorithm = 'SHA1',
  int? timestampMs,
}) async {
  final keyBytes = base32Decode(secretBase32);
  if (keyBytes.isEmpty) return null;

  final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
  final counter = ts ~/ 1000 ~/ period;
  final message = Uint8List(8);
  final view = ByteData.view(message.buffer);
  view.setUint32(0, counter >> 32);
  view.setUint32(4, counter & 0xffffffff);

  final mac = await _macFor(
    algorithm,
  ).calculateMac(message, secretKey: SecretKey(keyBytes));
  final sig = mac.bytes;
  final offset = sig[sig.length - 1] & 0x0f;
  final binary =
      ((sig[offset] & 0x7f) << 24) |
      (sig[offset + 1] << 16) |
      (sig[offset + 2] << 8) |
      sig[offset + 3];
  final mod = math.pow(10, digits).toInt();
  return (binary % mod).toString().padLeft(digits, '0');
}

/// Seconds left in the current TOTP window.
int secondsRemaining(int period, [int? timestampMs]) {
  final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
  return period - ((ts ~/ 1000) % period);
}

/// Parse an otpauth://totp/... URI (from a QR code) into an entry map, or null.
Map<String, dynamic>? parseOtpauthUri(String uri) {
  try {
    final url = Uri.parse(uri.trim());
    if (url.scheme != 'otpauth') return null;
    if (url.host.toLowerCase() != 'totp') return null; // HOTP not supported

    final secret = (url.queryParameters['secret'] ?? '').replaceAll(
      RegExp(r'\s+'),
      '',
    );
    if (secret.isEmpty || !isValidTotpSecret(secret)) return null;

    final label = Uri.decodeComponent(url.path.replaceFirst(RegExp(r'^/'), ''));
    var issuer = url.queryParameters['issuer'] ?? '';
    var account = label;
    if (label.contains(':')) {
      final parts = label.split(':');
      if (issuer.isEmpty) issuer = parts.first.trim();
      account = parts.sublist(1).join(':').trim();
    }

    return {
      'issuer': issuer.trim(),
      'label': account.trim(),
      'secret': secret,
      'digits': int.tryParse(url.queryParameters['digits'] ?? '') ?? 6,
      'period': int.tryParse(url.queryParameters['period'] ?? '') ?? 30,
      'algorithm': (url.queryParameters['algorithm'] ?? 'SHA1').toUpperCase(),
    };
  } catch (_) {
    return null;
  }
}
