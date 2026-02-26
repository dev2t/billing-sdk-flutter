# Billing Flutter SDK

Flutter SDK for **billing token verification**, **in-memory state for add-on checks**, **sync from billing server**, and **paste-and-verify** flow. Used by client-only apps (e.g. Scomm Flutter app); the only server is the Billing API.

---

## Status

**In development.** Implementation is driven by **[PLAN.md](PLAN.md)** – start there for responsibilities, API surface, and implementation steps.

---

## SDK Responsibilities

1. **Init** – On app start, decode the saved signed JSON and keep the decoded data **in memory** for the dev to use for **add-on checks**.
2. **Sync online** – Expose an **API** for the “sync from billing server” use case (e.g. when the user taps a sync button in the UI). Sync is done against the Billing API using a **unique id** (user OID, SSO id, or email).
3. **Paste + verify** – **Accept pasted JSON**, **verify** it, and **expose the data** to the app to save. On **success**: app saves the data. On **failure**: SDK exposes the **error cause** so the app can show an **error notification** with the failure reason.

---

## Target API (from PLAN.md)

```dart
import 'package:billing_flutter_sdk/billing_flutter_sdk.dart';

// 1) Init on app start (saved token from app storage)
BillingSdk.init(savedSignedJson);
BillingSdk.getPayload();  // use for add-on checks

// 2) Sync from server (e.g. when user taps Sync button)
await BillingSdk.syncFromServer(uniqueId: userOidOrSsoIdOrEmail);

// 3) Paste + verify (when user pastes token)
final result = BillingSdk.verifyAndDecode(pastedJson);
// Success: save token/payload in app. Failure: show result.error.message in notification.
```

---

## Docs

- **[PLAN.md](PLAN.md)** – Development plan: responsibilities, API, layout, implementation steps, Billing API contract.

---

## Development

```bash
cd billing_flutter_sdk
flutter pub get
flutter test
flutter run
```

Follow **PLAN.md** for implementation order.
