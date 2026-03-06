/// Shared PEM validation for public keys (RFC 7468).

const String _beginPublicKey = '-----BEGIN PUBLIC KEY-----';
const String _endPublicKey = '-----END PUBLIC KEY-----';

/// Validates that [content] contains valid public key PEM boundaries.
/// Throws [FormatException] if missing or malformed.
void validatePublicKeyPem(String content) {
  final trimmed = content.trim();
  if (!trimmed.contains(_beginPublicKey) || !trimmed.contains(_endPublicKey)) {
    throw FormatException(
      'Content does not contain a valid public key PEM. '
      'Expected "$_beginPublicKey" and "$_endPublicKey".',
    );
  }
  final beginIndex = trimmed.indexOf(_beginPublicKey);
  final endIndex = trimmed.indexOf(_endPublicKey);
  if (endIndex <= beginIndex) {
    throw FormatException(
      'Invalid PEM structure: END must appear after BEGIN.',
    );
  }
}
