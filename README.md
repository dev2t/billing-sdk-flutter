# Billing Flutter SDK

Flutter SDK for billing token verification, in-memory entitlements, sync from the Billing API, and paste-and-verify flows. For client-only apps (e.g. Scomm); the only backend is the Billing API.

---

## Features

- **Init** – Decode saved signed JWT on app start and keep payload in memory for add-on checks.
- **Sync** – Sync billing from the server by user id (email or SSO id).
- **Paste + verify** – Verify pasted token and expose payload (or a user-facing error) so the app can persist and show notifications.

---

## Installation

Add the package to your app’s `pubspec.yaml`:

```yaml
dependencies:
  billing_flutter_sdk:
    path: ../billing_flutter_sdk   # or your path / git ref
```

Then run:

```bash
flutter pub get
```

---

## Setup

1. **Configure** the SDK once (e.g. at app startup), before any other calls:

```dart
import 'package:billing_flutter_sdk/billing_flutter_sdk.dart';

void main() {
  BillingSdk.configure(
    billingApiBaseUrl: 'https://billing.example.com',
    publicKeyPem: null, // optional; omit to use SDK default (set for production)
  );
  runApp(MyApp());
}
```

2. **Init** on app start with the saved token from your storage (e.g. secure storage). If you have no token yet, pass `null`.

```dart
// In your app’s init flow (e.g. after reading from secure storage)
final savedToken = await storage.readBillingToken(); // your code
BillingSdk.init(savedToken);
```

---

## Usage

### Add-on checks

After `init` (or after a successful sync/verify), use the current payload for entitlements:

```dart
final payload = BillingSdk.getPayload();
if (payload != null && payload.hasSubscription('sub_premium')) {
  // Show premium feature
}
```

### Sync from server

Call when the user taps “Sync billing” (or similar). Use email or SSO id as required by your Billing API.

```dart
final result = await BillingSdk.syncFromServer(uniqueId: userEmailOrSsoId);
switch (result) {
  case SyncSuccess():
    // Optionally persist the new token; payload is already in memory
  case SyncFailure(:final message):
    // Show message in a snackbar or dialog
}
```

You can also pass `email:` or `ssoId:` explicitly instead of `uniqueId:`.

### Paste + verify

When the user pastes a token (e.g. from the billing portal):

```dart
final result = BillingSdk.verifyAndDecode(pastedJson);
switch (result) {
  case VerifySuccess(:final payload):
    // Persist pastedJson (and/or payload) for init on next launch
  case VerifyFailure(:final error):
    // Show error.message in an error notification
}
```

---

## Configuration

| Option | Description |
|--------|-------------|
| `billingApiBaseUrl` | Base URL of the Billing API (required for `syncFromServer`). |
| `publicKeyPem` | PEM string to verify JWTs. If omitted, the SDK uses an embedded default; **set from your Billing API in production.** |

---

## Important

- **Persistence** – The SDK does not persist tokens. Your app must save/load the raw token and pass it to `init` on launch.
- **Errors** – The SDK returns user-facing messages (`BillingTokenError.message`, `SyncFailure.message`). Your app should show them (e.g. snackbar, dialog).

---

## Development

From the SDK project root:

```bash
flutter pub get
flutter test
flutter run
```

- **[PLAN.md](PLAN.md)** – Development plan, API contract, and Billing API alignment.
- **[CODE_REVIEW.md](CODE_REVIEW.md)** – Code review flow and reviewer checklist.
