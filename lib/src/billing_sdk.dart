import 'package:billing_flutter_sdk/src/api/billing_api_client.dart';
import 'package:billing_flutter_sdk/src/keys/default_public_key.dart';
import 'package:billing_flutter_sdk/src/keys/public_key_loader.dart';
import 'package:billing_flutter_sdk/src/keys/public_key_loader_asset.dart';
import 'package:billing_flutter_sdk/src/models/billing_token_error.dart';
import 'package:billing_flutter_sdk/src/models/billing_token_payload.dart';
import 'package:billing_flutter_sdk/src/verification/token_verifier.dart';

/// Billing Flutter SDK: init from saved token, sync from server, paste+verify.
///
/// Call [configure] before first use (at least [publicKeyPem] from Billing API).
/// Then [init] on app start with saved token, and use [getPayload] for add-on checks.
class BillingSdk {
  BillingSdk._();

  static String? _billingApiBaseUrl;
  static String? _publicKeyPem;
  static TokenVerifier? _verifier;
  static BillingApiClient? _apiClient;

  static BillingTokenPayload? _currentPayload;

  /// Configures the SDK. Call before [init], [syncFromServer], or [verifyAndDecode].
  ///
  /// [billingApiBaseUrl] – base URL for sync (e.g. `https://billing.example.com`).
  /// [publicKeyPem] – PEM string to verify JWTs; if null, uses embedded default
  /// (replace with key from Billing API in production).
  /// [publicKeyPath] – path to a .pem file; file content is read and validated for
  /// standard PEM boundaries (-----BEGIN PUBLIC KEY----- / -----END PUBLIC KEY-----).
  /// Not supported on web (throws [UnsupportedError]); use [publicKeyPem] there.
  ///
  /// For embedding the key in your build, use [configureWithAsset] with an asset path
  /// (e.g. `keys/billing_public.pem`; avoid paths starting with `assets/` on web).
  static void configure({
    String? billingApiBaseUrl,
    String? publicKeyPem,
    String? publicKeyPath,
  }) {
    if (billingApiBaseUrl != null) _billingApiBaseUrl = billingApiBaseUrl;
    if (publicKeyPem != null) _publicKeyPem = publicKeyPem;
    if (publicKeyPath != null && publicKeyPath.trim().isNotEmpty) {
      _publicKeyPem = loadPublicKeyFromPath(publicKeyPath.trim());
    }
    _verifier = null;
    _apiClient = null;
  }

  /// Configures the SDK using a public key loaded from a Flutter asset.
  /// The key is embedded at build time. Validates PEM boundaries before use.
  ///
  /// Add the .pem file to your `pubspec.yaml` under `flutter: assets:` (e.g. `keys/billing_public.pem`).
  static Future<void> configureWithAsset({
    String? billingApiBaseUrl,
    required String publicKeyAsset,
  }) async {
    final pem = await loadPublicKeyFromAsset(publicKeyAsset);
    configure(billingApiBaseUrl: billingApiBaseUrl, publicKeyPem: pem);
  }

  /// Resets all static state. For testing only.
  static void resetForTesting() {
    _billingApiBaseUrl = null;
    _publicKeyPem = null;
    _verifier = null;
    _apiClient = null;
    _currentPayload = null;
  }

  static TokenVerifier get _verifierOrThrow {
    final pem = _publicKeyPem ?? defaultPublicKeyPem;

    return _verifier ??= TokenVerifier(publicKeyPem: pem);
  }

  static BillingApiClient get _apiClientOrThrow {
    final base = _billingApiBaseUrl;

    if (base == null || base.isEmpty) {
      throw StateError(
        'BillingSdk: call configure(billingApiBaseUrl: ...) before syncFromServer.',
      );
    }

    return _apiClient ??= BillingApiClient(baseUrl: base);
  }

  /// Initializes the SDK with the saved signed token (e.g. from secure storage).
  /// On success, stores payload in memory for [getPayload]. On null/invalid/expired, state stays empty.
  static void init(String? savedSignedJson) {
    if (savedSignedJson == null || savedSignedJson.trim().isEmpty) {
      _currentPayload = null;
      return;
    }

    final result = _verifierOrThrow.verifyAndDecode(savedSignedJson.trim());

    switch (result) {
      case VerifySuccess(:final payload):
        _currentPayload = payload;
      case VerifyFailure():
        _currentPayload = null;
    }
  }

  /// Returns the current in-memory payload, or null if not initialized or invalid.
  static BillingTokenPayload? getPayload() => _currentPayload;

  /// Syncs from the Billing API by user identifier. On success, updates in-memory state.
  /// Returns [SyncResult]; on failure, use the message for an error notification.
  static Future<SyncResult> syncFromServer({
    String? email,
    String? ssoId,
    String? uniqueId,
  }) async {
    String? emailParam = email;
    String? ssoIdParam = ssoId;

    if (uniqueId != null && uniqueId.isNotEmpty) {
      if (uniqueId.contains('@')) {
        emailParam = uniqueId;
      } else {
        ssoIdParam = uniqueId;
      }
    }

    if ((emailParam == null || emailParam.isEmpty) &&
        (ssoIdParam == null || ssoIdParam.isEmpty)) {
      return const SyncFailure(message: 'Missing user identifier.');
    }

    final client = _apiClientOrThrow;
    final result = await client.fetchSdkToken(
      email: emailParam,
      ssoId: ssoIdParam,
    );

    switch (result) {
      case SyncSuccess(:final signedToken):
        final verifyResult = _verifierOrThrow.verifyAndDecode(signedToken);

        switch (verifyResult) {
          case VerifySuccess(:final payload):
            _currentPayload = payload;
            return result;
          case VerifyFailure(:final error):
            return SyncFailure(message: error.message);
        }
      case SyncFailure():
        return result;
    }
  }

  /// Verifies pasted JSON (signed token) and returns payload or error.
  /// On success, updates in-memory state and the app should persist the raw token for [init] on next launch.
  /// On failure, show [BillingTokenError.message] in an error notification.
  static VerifyResult verifyAndDecode(String pastedJson) {
    final result = _verifierOrThrow.verifyAndDecode(pastedJson);

    switch (result) {
      case VerifySuccess(:final payload):
        _currentPayload = payload;
      case VerifyFailure():
        break;
    }

    return result;
  }
}
