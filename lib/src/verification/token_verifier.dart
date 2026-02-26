import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../models/billing_subscription.dart';
import '../models/billing_token_error.dart';
import '../models/billing_token_payload.dart';

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
        return _failure(BillingTokenErrorReason.missingClaims);
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

  VerifyFailure _failure(BillingTokenErrorReason reason) {
    return VerifyFailure(
      BillingTokenError(message: _userMessage(reason), reason: reason),
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

  /// Maps JWT payload map (snake_case claims) to [BillingTokenPayload].
  /// Canonical shape per PLAN §8.2: subscriptions[], sso_id, billing_email, payload_version.
  static BillingTokenPayload? _payloadFromMap(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;

    final payingPartyId = raw['paying_party_id'];
    final exp = raw['exp'];
    final subscriptionsRaw = raw['subscriptions'];
    final ssoId = raw['sso_id'];
    final billingEmail = raw['billing_email'];
    final payloadVersion = raw['payload_version'];

    if (payingPartyId is! String) return null;
    if (exp is! int) return null;
    if (ssoId is! String) return null;
    if (billingEmail is! String) return null;
    if (subscriptionsRaw is! List || subscriptionsRaw.isEmpty) return null;

    final version = payloadVersion is int
        ? payloadVersion
        : (payloadVersion is num ? payloadVersion.toInt() : 1);

    final subs = _parseSubscriptions(subscriptionsRaw);
    if (subs == null) return null;

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      exp * 1000,
      isUtc: true,
    );

    return BillingTokenPayload(
      payingPartyId: payingPartyId,
      ssoId: ssoId,
      billingEmail: billingEmail,
      organizationName: raw['organization_name'] is String
          ? raw['organization_name'] as String
          : null,
      subscriptions: subs,
      expiresAt: expiresAt,
      payloadVersion: version,
      issuedAt: _parseOptionalEpoch(raw['iat']),
      issuer: raw['iss'] is String ? raw['iss'] as String : null,
      audience: raw['aud'] is String ? raw['aud'] as String : null,
      userPartyId: raw['user_party_id'] is String
          ? raw['user_party_id'] as String
          : null,
      ssoIdGlobal: raw['sso_id_global'] is String
          ? raw['sso_id_global'] as String
          : null,
      gracePeriodDays: raw['grace_period_days'] is int
          ? raw['grace_period_days'] as int
          : null,
      monthlyBillingAnchor: raw['monthly_billing_anchor'] is int
          ? raw['monthly_billing_anchor'] as int
          : null,
      annualBillingAnchor: raw['annual_billing_anchor'] is int
          ? raw['annual_billing_anchor'] as int
          : null,
    );
  }

  static DateTime? _parseOptionalEpoch(dynamic value) {
    if (value is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
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
    final subscriptionId = m['subscription_id'];
    final planId = m['plan_id'];
    final productId = m['product_id'];
    final planName = m['plan_name'];
    final productName = m['product_name'];
    final status = m['subscription_status'];
    final periodStart = m['current_period_start'];
    final periodEnd = m['current_period_end'];
    final pricingId = m['pricing_id'];
    final billingInterval = m['billing_interval'];

    if (subscriptionId is! String ||
        planId is! String ||
        productId is! String ||
        planName is! String ||
        productName is! String ||
        status is! String ||
        periodStart is! int ||
        periodEnd is! int ||
        pricingId is! String ||
        billingInterval is! String) {
      return null;
    }

    return BillingSubscription(
      subscriptionId: subscriptionId,
      planId: planId,
      productId: productId,
      planName: planName,
      productName: productName,
      subscriptionStatus: status,
      currentPeriodStart: DateTime.fromMillisecondsSinceEpoch(
        periodStart * 1000,
        isUtc: true,
      ),
      currentPeriodEnd: DateTime.fromMillisecondsSinceEpoch(
        periodEnd * 1000,
        isUtc: true,
      ),
      pricingId: pricingId,
      billingInterval: billingInterval,
      assignedUserPartyId: m['assigned_user_party_id'] is String
          ? m['assigned_user_party_id'] as String
          : null,
      currencyCode: m['currency_code'] is String
          ? m['currency_code'] as String
          : null,
      basePrice: m['base_price'] is num ? m['base_price'] as num : null,
    );
  }
}
