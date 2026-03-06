/// Stub for environments that don't support file access (e.g. web).
/// Use [loadPublicKeyFromPath] on mobile/desktop only.

/// Loads public key PEM from file at [path].
/// On web this throws [UnsupportedError]. On IO platforms use [public_key_loader_io.dart].
String loadPublicKeyFromPath(String path) {
  throw UnsupportedError(
    'Loading public key from file path is not supported on this platform (e.g. web). '
    'Use BillingSdk.configure(publicKeyPem: ...) with the key content instead.',
  );
}
