import 'dart:io';

import 'pem_validation.dart';

/// Loads public key PEM from file at [path].
/// Validates that the content contains the standard PEM boundaries.
/// Throws [FormatException] if file content is not valid PEM.
String loadPublicKeyFromPath(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw FormatException('Public key file not found: $path');
  }
  final content = file.readAsStringSync().trim();
  validatePublicKeyPem(content);
  return content;
}
