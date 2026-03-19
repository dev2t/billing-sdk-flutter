/// Default public key PEM for verifying Billing API JWTs (ES256).
///
/// Replace with the actual public key from your Billing API (e.g. from
/// GET /api/billing/public-key) or set via [BillingSdk.configure].
///
/// For production, the host app must call [BillingSdk.configure] with
/// [publicKeyPem] from the Billing API.
/// Key below is for unit tests only. Example app uses [keys/billing_public.pem] (your backend key).
const String defaultPublicKeyPem = '''
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEeEVCorHYleEEXenCf2NUQK08nr66
xw3CP4f/pW1XBukGklwC8ghepXE6CfPoWyGGG8c5XvM7EpQyZq5VaWeanQ==
-----END PUBLIC KEY-----
''';
