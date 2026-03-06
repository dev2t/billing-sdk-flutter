import 'billing_subscription.dart';
import 'paying_party.dart';
import 'using_party_info.dart';

/// One mailbox (user/using party) with paying party and subscriptions.
/// From BILLING_TOKEN_PAYLOAD.md – each element of `mailboxes[]`.
class Mailbox {
  const Mailbox({
    required this.mailboxId,
    required this.payingParty,
    required this.usingPartyInfo,
    required this.subscriptions,
  });

  final String mailboxId;
  final PayingParty payingParty;
  final List<UsingPartyInfo> usingPartyInfo;
  final List<BillingSubscription> subscriptions;
}
