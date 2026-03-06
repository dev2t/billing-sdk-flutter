/// A single subscription in the billing token payload.
/// Each element of top-level `subscriptions[]`.
class BillingSubscription {
  const BillingSubscription({
    required this.subscriptionId,
    required this.planId,
    required this.productId,
    required this.planName,
    required this.productName,
    required this.subscriptionStatus,
    required this.validUntil,
    this.assignedUserPartyId,
  });

  final String subscriptionId;
  final String planId;
  final String productId;
  final String planName;
  final String productName;
  final String subscriptionStatus;
  final DateTime validUntil;
  final String? assignedUserPartyId;

  /// Whether this subscription is currently active (e.g. active, trialing).
  bool get isActive =>
      subscriptionStatus.toLowerCase() == 'active' ||
      subscriptionStatus.toLowerCase() == 'trialing';

  /// Whether the validity period has ended (now > valid_until).
  bool get isPeriodEnded => DateTime.now().isAfter(validUntil);
}
