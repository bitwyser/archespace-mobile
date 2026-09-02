/// Helpers for validating authenticator (TOTP) codes entered for two-factor
/// auth. Codes are the standard 6 digits; input is normalized so a code pasted
/// with spaces still matches.
library;

const int totpCodeLength = 6;

/// Strip everything except digits.
String normalizeTotpCode(String value) =>
    value.replaceAll(RegExp('[^0-9]'), '');

/// Returns an error message, or null when the code is well-formed.
String? validateTotpCode(String value) {
  final code = normalizeTotpCode(value);
  if (code.length != totpCodeLength) {
    return 'Enter the $totpCodeLength-digit code from your authenticator app.';
  }
  return null;
}
