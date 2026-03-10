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

      final payloadMap = jwt.payload;
      if (payloadMap is! Map<String, dynamic>) {
        return _failure(BillingTokenErrorReason.missingClaims, detail: 'Expected a JSON object payload.');
      }
      try {
        final payload = BillingTokenPayload.fromJson(payloadMap);
        return VerifySuccess(payload);
      } on FormatException catch (e) {
        return _failure(BillingTokenErrorReason.missingClaims, detail: e.message);
      }
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

}
