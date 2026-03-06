import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../models/billing_subscription.dart';
import '../models/billing_token_error.dart';
import '../models/billing_token_payload.dart';
import '../models/paying_party.dart';

/// Verifies and decodes a signed JWT into [BillingTokenPayload] or returns
/// a [BillingTokenError] with a user-facing message.
class TokenVerifier {
  TokenVerifier({required String publicKeyPem})
    : _publicKey = RSAPublicKey(publicKeyPem);

  final RSAPublicKey _publicKey;

  /// Verifies the token and returns either [VerifySuccess] with payload or
  /// [VerifyFailure] with a user-facing error for the app to show.
  VerifyResult verifyAndDecode(String signedToken) {
    final trimmed = signedToken.trim();

    if (trimmed.isEmpty) {
      return _failure(BillingTokenErrorReason.malformed);
    }

    try {
      final jwt = JWT.tryVerify(
        trimmed,
        _publicKey,
        checkExpiresIn: true,
        checkNotBefore: false,
      );

      if (jwt == null) {
        return _failure(BillingTokenErrorReason.invalidSignature);
      }

      final payload = _payloadFromMap(jwt.payload);
      if (payload == null) {
        final detail = _missingClaimsDetail(jwt.payload);
        return _failure(BillingTokenErrorReason.missingClaims, detail: detail);
      }

      return VerifySuccess(payload);
    } on JWTExpiredException {
      return _failure(BillingTokenErrorReason.expired);
    } on JWTException catch (e) {
      final reason = _reasonFromMessage(e.message);

      return VerifyFailure(
        BillingTokenError(
          message: _userMessage(reason, e.message),
          reason: reason,
        ),
      );
    } catch (_) {
      return _failure(BillingTokenErrorReason.malformed);
    }
  }

  VerifyFailure _failure(BillingTokenErrorReason reason, {String? detail}) {
    var message = _userMessage(reason);
    if (reason == BillingTokenErrorReason.missingClaims && detail != null && detail.isNotEmpty) {
      message = '$message $detail';
    }
    return VerifyFailure(
      BillingTokenError(message: message, reason: reason),
    );
  }

  BillingTokenErrorReason _reasonFromMessage(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('expired')) return BillingTokenErrorReason.expired;

    if (lower.contains('signature')) {
      return BillingTokenErrorReason.invalidSignature;
    }

    if (lower.contains('invalid') || lower.contains('malformed')) {
      return BillingTokenErrorReason.malformed;
    }

    return BillingTokenErrorReason.unknown;
  }

  String _userMessage(BillingTokenErrorReason reason, [String fallback = '']) {
    return switch (reason) {
      BillingTokenErrorReason.invalidSignature =>
        'Invalid token. It may have been copied incorrectly.',
      BillingTokenErrorReason.expired =>
        'This token has expired. Please sync or get a new token from the billing portal.',
      BillingTokenErrorReason.malformed =>
        'Invalid format. Please paste the full token from the billing portal.',
      BillingTokenErrorReason.missingClaims =>
        'Token is missing required data.',
      BillingTokenErrorReason.unknown =>
        fallback.isNotEmpty
            ? fallback
            : 'Invalid token. It may have been copied incorrectly.',
    };
  }

  /// Maps JWT payload to [BillingTokenPayload].
  /// Flat shape: payload_version, iss, aud, iat, exp, paying_party, subscriptions[].
  static dynamic _get(Map<String, dynamic> m, String snake, String camel) {
    return m[snake] ?? m[camel];
  }

  /// Default expiry when token has no exp claim (treat as long-lived).
  static final DateTime _defaultExpiresAt = DateTime.utc(2099, 12, 31);

  /// Returns a short description of what is missing when parsing fails, or null.
  static String? _missingClaimsDetail(dynamic raw) {
    if (raw is! Map<String, dynamic>) return 'Expected a JSON object payload.';
    final payloadVersion = _get(raw, 'payload_version', 'payloadVersion');
    if (payloadVersion == null) return 'payload_version (number) required.';
    // exp is optional; if missing we use _defaultExpiresAt in _payloadFromMap
    final payingPartyRaw = _get(raw, 'paying_party', 'payingParty');
    if (payingPartyRaw == null) return 'paying_party object required.';
    if (payingPartyRaw is! Map<String, dynamic>) return 'paying_party must be an object.';
    final id = _get(payingPartyRaw, 'id', 'id');
    final ssoId = _get(payingPartyRaw, 'sso_id', 'ssoId');
    final billingEmail = _get(payingPartyRaw, 'billing_email', 'billingEmail');
    if (id is! String || id.isEmpty) return 'paying_party.id required.';
    if (ssoId is! String || ssoId.isEmpty) return 'paying_party.sso_id required.';
    if (billingEmail is! String) return 'paying_party.billing_email required.';
    final subscriptionsRaw = raw['subscriptions'];
    if (subscriptionsRaw == null) return 'subscriptions array required.';
    if (subscriptionsRaw is! List) return 'subscriptions must be an array.';
    for (var i = 0; i < subscriptionsRaw.length; i++) {
      final item = subscriptionsRaw[i];
      if (item is! Map<String, dynamic>) return 'subscriptions[$i] must be an object.';
      final subId = _get(item, 'subscription_id', 'subscriptionId');
      final planId = _get(item, 'plan_id', 'planId');
      final productId = _get(item, 'product_id', 'productId');
      final planName = _get(item, 'plan_name', 'planName');
      final productName = _get(item, 'product_name', 'productName');
      final status = _get(item, 'subscription_status', 'subscriptionStatus');
      final validUntil = _get(item, 'valid_until', 'validUntil');
      if (subId is! String) return 'subscriptions[$i].subscription_id required.';
      if (planId is! String) return 'subscriptions[$i].plan_id required.';
      if (productId is! String) return 'subscriptions[$i].product_id required.';
      if (planName is! String) return 'subscriptions[$i].plan_name required.';
      if (productName is! String) return 'subscriptions[$i].product_name required.';
      if (status is! String) return 'subscriptions[$i].subscription_status required.';
      if (validUntil == null) return 'subscriptions[$i].valid_until required.';
      if (validUntil is! int && validUntil is! num) return 'subscriptions[$i].valid_until must be a number (Unix timestamp).';
    }
    return null;
  }

  static BillingTokenPayload? _payloadFromMap(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;

    final payloadVersion = _get(raw, 'payload_version', 'payloadVersion');
    final exp = raw['exp'];
    final payingPartyRaw = _get(raw, 'paying_party', 'payingParty');
    final subscriptionsRaw = raw['subscriptions'];

    final version = payloadVersion is int
        ? payloadVersion
        : (payloadVersion is num ? payloadVersion.toInt() : null);
    if (version == null) return null;
    final expInt = exp is int ? exp : (exp is num ? exp.toInt() : null);
    final expiresAt = expInt != null
        ? DateTime.fromMillisecondsSinceEpoch(expInt * 1000, isUtc: true)
        : _defaultExpiresAt;
    final payingParty = _parsePayingParty(payingPartyRaw);
    if (payingParty == null) return null;
    if (subscriptionsRaw is! List) return null;
    final subscriptions = _parseSubscriptions(subscriptionsRaw);
    if (subscriptions == null) return null;

    return BillingTokenPayload(
      payloadVersion: version,
      expiresAt: expiresAt,
      payingParty: payingParty,
      subscriptions: subscriptions,
      issuedAt: _parseOptionalEpoch(raw['iat']),
      issuer: raw['iss'] is String ? raw['iss'] as String : null,
      audience: raw['aud'] is String ? raw['aud'] as String : null,
    );
  }

  static DateTime? _parseOptionalEpoch(dynamic value) {
    if (value is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }

  static PayingParty? _parsePayingParty(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = _get(raw, 'id', 'id');
    final ssoId = _get(raw, 'sso_id', 'ssoId');
    final billingEmail = _get(raw, 'billing_email', 'billingEmail');
    if (id is! String || ssoId is! String || billingEmail is! String) {
      return null;
    }
    return PayingParty(
      id: id,
      ssoId: ssoId,
      billingEmail: billingEmail,
      organizationName: _get(raw, 'organization_name', 'organizationName') is String
          ? _get(raw, 'organization_name', 'organizationName') as String
          : null,
    );
  }

  static List<BillingSubscription>? _parseSubscriptions(dynamic list) {
    if (list is! List) return null;
    final result = <BillingSubscription>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) return null;
      final sub = _parseSubscription(item);
      if (sub == null) return null;
      result.add(sub);
    }
    return result;
  }

  static BillingSubscription? _parseSubscription(Map<String, dynamic> m) {
    final subscriptionId = _get(m, 'subscription_id', 'subscriptionId');
    final planId = _get(m, 'plan_id', 'planId');
    final productId = _get(m, 'product_id', 'productId');
    final planName = _get(m, 'plan_name', 'planName');
    final productName = _get(m, 'product_name', 'productName');
    final status = _get(m, 'subscription_status', 'subscriptionStatus');
    final validUntil = _get(m, 'valid_until', 'validUntil');

    final validUntilInt = validUntil is int ? validUntil : (validUntil is num ? validUntil.toInt() : null);
    if (subscriptionId is! String ||
        planId is! String ||
        productId is! String ||
        planName is! String ||
        productName is! String ||
        status is! String ||
        validUntilInt == null) {
      return null;
    }

    final assigned = _get(m, 'assigned_user_party_id', 'assignedUserPartyId');
    final assignedUserPartyId = assigned is String && assigned.isNotEmpty
        ? assigned
        : null;

    return BillingSubscription(
      subscriptionId: subscriptionId,
      planId: planId,
      productId: productId,
      planName: planName,
      productName: productName,
      subscriptionStatus: status,
      validUntil: DateTime.fromMillisecondsSinceEpoch(
        validUntilInt * 1000,
        isUtc: true,
      ),
      assignedUserPartyId: assignedUserPartyId,
    );
  }
}
