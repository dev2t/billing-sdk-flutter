import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

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
      return VerifyFailure(const BillingTokenError(
        message: 'Invalid format. Please paste the full token from the billing portal.',
        reason: BillingTokenErrorReason.malformed,
      ));
    }

    try {
      final jwt = JWT.tryVerify(
        trimmed,
        _publicKey,
        checkExpiresIn: true,
        checkNotBefore: false,
      );

      if (jwt == null) {
        return VerifyFailure(const BillingTokenError(
          message: 'Invalid token. It may have been copied incorrectly.',
          reason: BillingTokenErrorReason.invalidSignature,
        ));
      }

      final payload = _payloadFromMap(jwt.payload);
      if (payload == null) {
        return VerifyFailure(const BillingTokenError(
          message: 'Token is missing required data.',
          reason: BillingTokenErrorReason.missingClaims,
        ));
      }

      return VerifySuccess(payload);
    } on JWTExpiredException {
      return VerifyFailure(const BillingTokenError(
        message:
            'This token has expired. Please sync or get a new token from the billing portal.',
        reason: BillingTokenErrorReason.expired,
      ));
    } on JWTException catch (e) {
      final reason = _reasonFromMessage(e.message);
      return VerifyFailure(BillingTokenError(
        message: _userMessage(reason, e.message),
        reason: reason,
      ));
    } catch (_) {
      return VerifyFailure(const BillingTokenError(
        message: 'Invalid format. Please paste the full token from the billing portal.',
        reason: BillingTokenErrorReason.malformed,
      ));
    }
  }

  BillingTokenErrorReason _reasonFromMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('expired')) return BillingTokenErrorReason.expired;
    if (lower.contains('signature')) return BillingTokenErrorReason.invalidSignature;
    if (lower.contains('invalid') || lower.contains('malformed')) {
      return BillingTokenErrorReason.malformed;
    }
    return BillingTokenErrorReason.unknown;
  }

  String _userMessage(BillingTokenErrorReason reason, String fallback) {
    return switch (reason) {
      BillingTokenErrorReason.invalidSignature =>
        'Invalid token. It may have been copied incorrectly.',
      BillingTokenErrorReason.expired =>
        'This token has expired. Please sync or get a new token from the billing portal.',
      BillingTokenErrorReason.malformed =>
        'Invalid format. Please paste the full token from the billing portal.',
      BillingTokenErrorReason.missingClaims => 'Token is missing required data.',
      BillingTokenErrorReason.unknown => fallback.isNotEmpty
          ? fallback
          : 'Invalid token. It may have been copied incorrectly.',
    };
  }

  /// Maps JWT payload map (snake_case claims) to [BillingTokenPayload].
  static BillingTokenPayload? _payloadFromMap(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;

    final payingPartyId = raw['paying_party_id'];
    final subscriptionIds = raw['subscription_ids'];
    final exp = raw['exp'];

    if (payingPartyId is! String) return null;
    if (subscriptionIds is! List) return null;
    if (exp is! int) return null;

    final subs = subscriptionIds
        .map((e) => e?.toString())
        .whereType<String>()
        .toList();

    final expiresAt =
        DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);

    final iat = raw['iat'];
    final issuedAt = iat is int
        ? DateTime.fromMillisecondsSinceEpoch(iat * 1000, isUtc: true)
        : null;

    return BillingTokenPayload(
      payingPartyId: payingPartyId,
      subscriptionIds: subs,
      expiresAt: expiresAt,
      email: raw['email'] is String ? raw['email'] as String : null,
      issuedAt: issuedAt,
      issuer: raw['iss'] is String ? raw['iss'] as String : null,
      audience: raw['aud'] is String ? raw['aud'] as String : null,
    );
  }
}
