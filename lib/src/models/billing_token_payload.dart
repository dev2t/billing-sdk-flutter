import 'billing_subscription.dart';
import 'paying_party.dart';

/// Decoded billing license token payload from the signed JWT.
/// Flat shape: payload_version, iss, aud, iat, exp, paying_party, subscriptions[].
class BillingTokenPayload {
  const BillingTokenPayload({
    required this.payloadVersion,
    required this.expiresAt,
    required this.payingParty,
    required this.subscriptions,
    this.issuedAt,
    this.issuer,
    this.audience,
  });

  final int payloadVersion;
  final DateTime expiresAt;
  final DateTime? issuedAt;
  final String? issuer;
  final String? audience;
  final PayingParty payingParty;
  final List<BillingSubscription> subscriptions;

  /// Convenience alias for [payingParty] (e.g. when migrating from mailbox-based payloads).
  PayingParty? get firstPayingParty => payingParty;

  /// List of subscription IDs.
  List<String> get subscriptionIds =>
      subscriptions.map((s) => s.subscriptionId).toList();

  /// Billing email from paying party.
  String? get email => payingParty.billingEmail.isNotEmpty ? payingParty.billingEmail : null;

  /// Active subscriptions only (status active or trialing).
  List<BillingSubscription> get activeSubscriptions =>
      subscriptions.where((s) => s.isActive).toList();

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
          payloadVersion == other.payloadVersion &&
          expiresAt == other.expiresAt &&
          payingParty == other.payingParty &&
          _listEquals(subscriptions, other.subscriptions);

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(payloadVersion, expiresAt, payingParty, Object.hashAll(subscriptions));
}
