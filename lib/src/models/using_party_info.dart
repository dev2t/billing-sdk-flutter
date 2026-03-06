/// One using party (user) in a mailbox.
/// From BILLING_TOKEN_PAYLOAD.md – `using_party_info[]` under each mailbox.
class UsingPartyInfo {
  const UsingPartyInfo({
    required this.userPartyId,
    required this.ssoIdGlobal,
    this.userEmail,
  });

  final String userPartyId;
  final String ssoIdGlobal;
  final String? userEmail;
}
