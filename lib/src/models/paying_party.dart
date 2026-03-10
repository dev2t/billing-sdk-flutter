import 'jwt_payload_keys.dart';

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

  /// Parses from JWT payload map (snake_case or camelCase). Throws [FormatException] if invalid.
  factory PayingParty.fromJson(Map<String, dynamic> json) {
    final id = getKey(json, 'id', 'id');
    final ssoId = getKey(json, 'sso_id', 'ssoId');
    final billingEmail = getKey(json, 'billing_email', 'billingEmail');
    if (id is! String || id.isEmpty) throw FormatException('paying_party.id required.');
    if (ssoId is! String || ssoId.isEmpty) throw FormatException('paying_party.sso_id required.');
    if (billingEmail is! String) throw FormatException('paying_party.billing_email required.');
    final org = getKey(json, 'organization_name', 'organizationName');
    return PayingParty(
      id: id,
      ssoId: ssoId,
      billingEmail: billingEmail,
      organizationName: org is String ? org : null,
    );
  }

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
