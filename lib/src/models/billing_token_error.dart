import 'billing_token_payload.dart';

/// Reason for billing token verification failure.
enum BillingTokenErrorReason {
  invalidSignature,
  expired,
  malformed,
  missingClaims,
  unknown,
}

/// Error returned when verification of a pasted/synced token fails.
/// Exposes a user-facing [message] for the app to show in a notification.
class BillingTokenError {
  const BillingTokenError({
    required this.message,
    this.reason = BillingTokenErrorReason.unknown,
  });

  final String message;
  final BillingTokenErrorReason reason;

  @override
  String toString() => 'BillingTokenError($reason): $message';
}

/// Result type for verifyAndDecode: either payload or error.
sealed class VerifyResult {}

class VerifySuccess implements VerifyResult {
  const VerifySuccess(this.payload);
  final BillingTokenPayload payload;
}

class VerifyFailure implements VerifyResult {
  const VerifyFailure(this.error);
  final BillingTokenError error;
}
