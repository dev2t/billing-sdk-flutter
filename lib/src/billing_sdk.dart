import 'dart:convert';

import 'package:billing_flutter_sdk/src/api/billing_api_client.dart';
import 'package:billing_flutter_sdk/src/keys/default_public_key.dart';
import 'package:billing_flutter_sdk/src/keys/public_key_loader.dart';
import 'package:billing_flutter_sdk/src/keys/public_key_loader_asset.dart';
import 'package:billing_flutter_sdk/src/logging/sdk_logger.dart';
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

  /// Last loaded key fingerprint (for debugging). Set when key is configured.
  static String? _loadedKeyFingerprint;

  /// Fingerprint of the currently configured public key (last 24 chars of base64 body).
  /// Use to verify the key in use matches your file (e.g. keys/billing_public.pem).
  static String? get loadedKeyFingerprint => _loadedKeyFingerprint;

  /// Short fingerprint of PEM content (last 24 chars of base64 body) for log verification.
  static String _pemFingerprint(String pem) {
    const begin = '-----BEGIN PUBLIC KEY-----';
    const end = '-----END PUBLIC KEY-----';
    final start = pem.indexOf(begin);
    final endIdx = pem.indexOf(end);
    if (start < 0 || endIdx <= start) return '?';
    final body = pem.substring(start + begin.length, endIdx).replaceAll(RegExp(r'\s'), '');
    return body.length >= 24 ? body.substring(body.length - 24) : body;
  }

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
      try {
        _publicKeyPem = loadPublicKeyFromPath(publicKeyPath.trim());
        _loadedKeyFingerprint = _pemFingerprint(_publicKeyPem!);
        BillingSdkLogger.info('Configured: public key from path', '${publicKeyPath.trim()} — fingerprint: $_loadedKeyFingerprint');
      } catch (e) {
        BillingSdkLogger.error('Configure: failed to load public key from path', '$publicKeyPath — $e');
        rethrow;
      }
    } else if (publicKeyPem != null) {
      _loadedKeyFingerprint = _pemFingerprint(publicKeyPem);
      BillingSdkLogger.info('Configured: public key set from PEM (${publicKeyPem.length} chars)', _loadedKeyFingerprint);
    }
    if (billingApiBaseUrl != null) {
      BillingSdkLogger.info('Configured: billingApiBaseUrl', billingApiBaseUrl);
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
    try {
      final pem = await loadPublicKeyFromAsset(publicKeyAsset);
      _loadedKeyFingerprint = _pemFingerprint(pem);
      configure(billingApiBaseUrl: billingApiBaseUrl, publicKeyPem: pem);
      BillingSdkLogger.info('Configured with asset: public key loaded', '$publicKeyAsset — fingerprint: $_loadedKeyFingerprint');
    } catch (e) {
      BillingSdkLogger.error('configureWithAsset failed', '$publicKeyAsset — $e');
      rethrow;
    }
  }

  /// Resets all static state. For testing only.
  static void resetForTesting() {
    _billingApiBaseUrl = null;
    _publicKeyPem = null;
    _verifier = null;
    _apiClient = null;
    _currentPayload = null;
    _loadedKeyFingerprint = null;
  }

  /// Reads the JWT header and returns the "alg" value (e.g. "ES256", "RS256").
  /// Use when verification fails to check if the token uses the expected algorithm.
  static String? getJwtAlg(String signedToken) {
    final trimmed = signedToken.trim();
    try {
      final parts = trimmed.split('.');
      if (parts.length < 2) return null;
      final raw = parts[0].replaceAll('-', '+').replaceAll('_', '/');
      final pad = raw.length % 4;
      final padded = pad == 2 ? '$raw==' : pad == 3 ? '$raw=' : raw;
      final decoded = utf8.decode(base64Url.decode(padded));
      final map = jsonDecode(decoded) as Map<String, dynamic>?;
      return map?['alg'] as String?;
    } catch (_) {
      return null;
    }
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
      BillingSdkLogger.info('init: no saved token — payload cleared');
      _currentPayload = null;
      return;
    }

    final result = _verifierOrThrow.verifyAndDecode(savedSignedJson.trim());

    switch (result) {
      case VerifySuccess(:final payload):
        _currentPayload = payload;
        BillingSdkLogger.success(
          'init: token verified — payingParty=${payload.payingParty.id}, subscriptions=${payload.subscriptionIds.length}',
        );
      case VerifyFailure(:final error):
        _currentPayload = null;
        BillingSdkLogger.error('init: token invalid', 'reason=${error.reason} — ${error.message}');
    }
  }

  /// Returns the current in-memory payload, or null if not initialized or invalid.
  static BillingTokenPayload? getPayload() => _currentPayload;

  /// Syncs from the Billing API. Requires [authorizationToken] (Bearer or SSO token). No email/ssoId.
  /// GET /api/billing/license with Authorization header. On success, updates in-memory state.
  /// Returns [SyncResult]; on failure, use the message for an error notification.
  static Future<SyncResult> syncFromServer({required String authorizationToken}) async {
    BillingSdkLogger.info('syncFromServer: requesting license from API');
    final client = _apiClientOrThrow;
    final result = await client.fetchLicense(authorizationToken: authorizationToken);

    switch (result) {
      case SyncSuccess(:final signedToken):
        final verifyResult = _verifierOrThrow.verifyAndDecode(signedToken);

        switch (verifyResult) {
          case VerifySuccess(:final payload):
            _currentPayload = payload;
            BillingSdkLogger.success(
              'syncFromServer: success — payingParty=${payload.payingParty.id}, subscriptions=${payload.subscriptionIds.length}',
            );
            return result;
          case VerifyFailure(:final error):
            BillingSdkLogger.error('syncFromServer: token from API failed verification', 'reason=${error.reason}');
            return SyncFailure(message: error.message);
        }
      case SyncFailure(:final message):
        BillingSdkLogger.error('syncFromServer: failed', message);
        return result;
    }
  }

  /// Verifies pasted JSON (signed token) and returns payload or error.
  /// On success, updates in-memory state and the app should persist the raw token for [init] on next launch.
  /// On failure, show [BillingTokenError.message] in an error notification.
  static VerifyResult verifyAndDecode(String pastedJson) {
    final result = _verifierOrThrow.verifyAndDecode(pastedJson.trim());

    switch (result) {
      case VerifySuccess(:final payload):
        _currentPayload = payload;
        BillingSdkLogger.success(
          'verifyAndDecode: success — payingParty=${payload.payingParty.id}, subscriptions=${payload.subscriptionIds.length}',
        );
      case VerifyFailure(:final error):
        BillingSdkLogger.error('verifyAndDecode: failed', 'reason=${error.reason} — ${error.message}');
    }

    return result;
  }
}
