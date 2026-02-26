import 'billing_subscription.dart';

/// Decoded billing token payload from the signed JWT.
///
/// Maps from JWT claims per PLAN §8.2 (canonical structure in Billing API repo
/// `docs/BILLING_TOKEN_PAYLOAD.md`). Supports payload_version for forward compatibility.
class BillingTokenPayload {
  const BillingTokenPayload({
    required this.payingPartyId,
    required this.ssoId,
    required this.billingEmail,
    required this.subscriptions,
    required this.expiresAt,
    required this.payloadVersion,
    this.organizationName,
    this.issuedAt,
    this.issuer,
    this.audience,
    this.userPartyId,
    this.ssoIdGlobal,
    this.gracePeriodDays,
    this.monthlyBillingAnchor,
    this.annualBillingAnchor,
  });

  // ---------- Paying party (required) ----------
  final String payingPartyId;
  final String ssoId;
  final String billingEmail;
  final String? organizationName;

  // ---------- Optional paying-party fields ----------
  final int? gracePeriodDays;
  final int? monthlyBillingAnchor;
  final int? annualBillingAnchor;

  // ---------- Subscriptions (required) ----------
  final List<BillingSubscription> subscriptions;

  // ---------- Standard & versioning ----------
  final DateTime expiresAt;
  final DateTime? issuedAt;
  final int payloadVersion;
  final String? issuer;
  final String? audience;

  // ---------- Optional "per user" (when token issued for a specific user) ----------
  final String? userPartyId;
  final String? ssoIdGlobal;

  /// Convenience: list of subscription IDs (from [subscriptions]).
  /// Use [subscriptions] for full details; use this for simple ID checks.
  List<String> get subscriptionIds =>
      subscriptions.map((s) => s.subscriptionId).toList();

  /// Alias for [billingEmail]. Use for add-on checks or display.
  String? get email => billingEmail.isNotEmpty ? billingEmail : null;

  /// Active subscriptions only (status active or trialing).
  List<BillingSubscription> get activeSubscriptions =>
      subscriptions.where((s) => s.isActive).toList();

  // Add-on checks: by ID below. Consider adding by-name (e.g. hasPlanByName, hasProductByName)
  // or combined filters (e.g. any-of list) if needed later.

  /// Whether this payload has an active subscription with the given subscription ID.
  bool hasSubscription(String subscriptionId) =>
      subscriptions.any((s) => s.subscriptionId == subscriptionId);

  /// Whether the payload has any subscription for the given plan (add-on check).
  bool hasPlan(String planId) =>
      subscriptions.any((s) => s.planId == planId && s.isActive);

  /// Whether the payload has any subscription for the given product (add-on check).
  bool hasProduct(String productId) =>
      subscriptions.any((s) => s.productId == productId && s.isActive);

  /// Whether the token is still valid (not expired).
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillingTokenPayload &&
          runtimeType == other.runtimeType &&
          payingPartyId == other.payingPartyId &&
          ssoId == other.ssoId &&
          billingEmail == other.billingEmail &&
          _listEquals(subscriptions, other.subscriptions) &&
          expiresAt == other.expiresAt &&
          payloadVersion == other.payloadVersion;

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        payingPartyId,
        ssoId,
        billingEmail,
        Object.hashAll(subscriptions),
        expiresAt,
        payloadVersion,
      );
}
