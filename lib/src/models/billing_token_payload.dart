/// Decoded billing token payload from the signed JWT.
///
/// Maps from JWT claims per PLAN §8.2:
/// - paying_party_id, subscription_ids, email, exp, iat, iss, aud.
class BillingTokenPayload {
  const BillingTokenPayload({
    required this.payingPartyId,
    required this.subscriptionIds,
    required this.expiresAt,
    this.email,
    this.issuedAt,
    this.issuer,
    this.audience,
  });

  final String payingPartyId;
  final List<String> subscriptionIds;
  final DateTime expiresAt;
  final String? email;
  final DateTime? issuedAt;
  final String? issuer;
  final String? audience;

  /// Whether this payload has an active subscription with the given id.
  bool hasSubscription(String subscriptionId) =>
      subscriptionIds.contains(subscriptionId);

  /// Whether the token is still valid (not expired).
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BillingTokenPayload &&
          runtimeType == other.runtimeType &&
          payingPartyId == other.payingPartyId &&
          _listEquals(subscriptionIds, other.subscriptionIds) &&
          expiresAt == other.expiresAt &&
          email == other.email;

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(payingPartyId, Object.hashAll(subscriptionIds), expiresAt, email);
}
