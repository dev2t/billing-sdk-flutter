/// A single subscription in the billing token payload.
///
/// Maps from JWT claim `subscriptions[]` per PLAN §8.2.
class BillingSubscription {
  const BillingSubscription({
    required this.subscriptionId,
    required this.planId,
    required this.productId,
    required this.planName,
    required this.productName,
    required this.subscriptionStatus,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.pricingId,
    required this.billingInterval,
    this.assignedUserPartyId,
    this.currencyCode,
    this.basePrice,
  });

  final String subscriptionId;
  final String planId;
  final String productId;
  final String planName;
  final String productName;
  final String subscriptionStatus;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final String pricingId;
  final String billingInterval;
  final String? assignedUserPartyId;
  final String? currencyCode;
  final num? basePrice;

  /// Whether this subscription is currently active (e.g. active, trialing).
  bool get isActive =>
      subscriptionStatus.toLowerCase() == 'active' ||
      subscriptionStatus.toLowerCase() == 'trialing';

  /// Whether the current period has ended.
  bool get isPeriodEnded => DateTime.now().isAfter(currentPeriodEnd);
}
