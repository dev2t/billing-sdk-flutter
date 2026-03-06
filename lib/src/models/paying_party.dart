/// Paying party (org) that owns the subscriptions.
/// Top-level `paying_party` or nested under a mailbox.
class PayingParty {
  const PayingParty({
    required this.id,
    required this.ssoId,
    required this.billingEmail,
    this.organizationName,
  });

  final String id;
  final String ssoId;
  final String billingEmail;
  final String? organizationName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayingParty &&
          id == other.id &&
          ssoId == other.ssoId &&
          billingEmail == other.billingEmail &&
          organizationName == other.organizationName;

  @override
  int get hashCode => Object.hash(id, ssoId, billingEmail, organizationName);
}
