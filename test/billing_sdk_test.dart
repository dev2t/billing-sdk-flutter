import 'package:billing_flutter_sdk/billing_flutter_sdk.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_test/flutter_test.dart';

// Test key pair matching lib/src/keys/default_public_key.dart (RS256)
const _rsaPrivKeyPem = '''
-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQC7VJTUt9Us8cKj
MzEfYyjiWA4R4/M2bS1GB4t7NXp98C3SC6dVMvDuictGeurT8jNbvJZHtCSuYEvu
NMoSfm76oqFvAp8Gy0iz5sxjZmSnXyCdPEovGhLa0VzMaQ8s+CLOyS56YyCFGeJZ
qgtzJ6GR3eqoYSW9b9UMvkBpZODSctWSNGj3P7jRFDO5VoTwCQAWbFnOjDfH5Ulg
p2PKSQnSJP3AJLQNFNe7br1XbrhV//eO+t51mIpGSDCUv3E0DDFcWDTH9cXDTTlR
ZVEiR2BwpZOOkE/Z0/BVnhZYL71oZV34bKfWjQIt6V/isSMahdsAASACp4ZTGtwi
VuNd9tybAgMBAAECggEBAKTmjaS6tkK8BlPXClTQ2vpz/N6uxDeS35mXpqasqskV
laAidgg/sWqpjXDbXr93otIMLlWsM+X0CqMDgSXKejLS2jx4GDjI1ZTXg++0AMJ8
sJ74pWzVDOfmCEQ/7wXs3+cbnXhKriO8Z036q92Qc1+N87SI38nkGa0ABH9CN83H
mQqt4fB7UdHzuIRe/me2PGhIq5ZBzj6h3BpoPGzEP+x3l9YmK8t/1cN0pqI+dQwY
dgfGjackLu/2qH80MCF7IyQaseZUOJyKrCLtSD/Iixv/hzDEUPfOCjFDgTpzf3cw
ta8+oE4wHCo1iI1/4TlPkwmXx4qSXtmw4aQPz7IDQvECgYEA8KNThCO2gsC2I9PQ
DM/8Cw0O983WCDY+oi+7JPiNAJwv5DYBqEZB1QYdj06YD16XlC/HAZMsMku1na2T
N0driwenQQWzoev3g2S7gRDoS/FCJSI3jJ+kjgtaA7Qmzlgk1TxODN+G1H91HW7t
0l7VnL27IWyYo2qRRK3jzxqUiPUCgYEAx0oQs2reBQGMVZnApD1jeq7n4MvNLcPv
t8b/eU9iUv6Y4Mj0Suo/AU8lYZXm8ubbqAlwz2VSVunD2tOplHyMUrtCtObAfVDU
AhCndKaA9gApgfb3xw1IKbuQ1u4IF1FJl3VtumfQn//LiH1B3rXhcdyo3/vIttEk
48RakUKClU8CgYEAzV7W3COOlDDcQd935DdtKBFRAPRPAlspQUnzMi5eSHMD/ISL
DY5IiQHbIH83D4bvXq0X7qQoSBSNP7Dvv3HYuqMhf0DaegrlBuJllFVVq9qPVRnK
xt1Il2HgxOBvbhOT+9in1BzA+YJ99UzC85O0Qz06A+CmtHEy4aZ2kj5hHjECgYEA
mNS4+A8Fkss8Js1RieK2LniBxMgmYml3pfVLKGnzmng7H2+cwPLhPIzIuwytXywh
2bzbsYEfYx3EoEVgMEpPhoarQnYPukrJO4gwE2o5Te6T5mJSZGlQJQj9q4ZB2Dfz
et6INsK0oG8XVGXSpQvQh3RUYekCZQkBBFcpqWpbIEsCgYAnM3DQf3FJoSnXaMhr
VBIovic5l0xFkEHskAjFTevO86Fsz1C2aSeRKSqGFoOQ0tmJzBEs1R6KqnHInicD
TQrKhArgLXX4v3CddjfTRJkFWDbE/CkvKZNOrcf1nhaGCPspRJj2KUkj1Fhl9Cnc
dn/RsYEONbwQSjIfMPkvxF+8HQ==
-----END PRIVATE KEY-----''';

/// Flat payload: payload_version, iss, aud, iat, exp, paying_party, subscriptions[].
String _createCanonicalBillingToken({Duration? expiresIn}) {
  final exp = expiresIn != null
      ? DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000
      : DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
  final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final validUntil = DateTime.now().toUtc().add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000;
  final jwt = JWT(
    {
      'payload_version': 1,
      'iss': 'https://billing.scomm.ai',
      'aud': 'scomm',
      'iat': iat,
      'exp': exp,
      'paying_party': {
        'id': 'party_456',
        'sso_id': 'sso_abc',
        'billing_email': 'billing@example.com',
        'organization_name': 'Acme Inc',
      },
      'subscriptions': [
        {
          'subscription_id': 'sub_canon_1',
          'plan_id': 'plan_premium',
          'product_id': 'prod_1',
          'plan_name': 'Premium',
          'product_name': 'Product One',
          'subscription_status': 'active',
          'valid_until': validUntil,
          'assigned_user_party_id': null,
        },
      ],
    },
  );
  return jwt.sign(RSAPrivateKey(_rsaPrivKeyPem), algorithm: JWTAlgorithm.RS256);
}

void main() {
  group('BillingSdk', () {
    setUp(() {
      BillingSdk.configure(
        billingApiBaseUrl: 'https://billing.example.com',
        publicKeyPem: null, // use default (matches test key)
      );
    });

    group('init', () {
      test('init(null) leaves payload null', () {
        BillingSdk.init(null);
        expect(BillingSdk.getPayload(), isNull);
      });

      test('init(empty string) leaves payload null', () {
        BillingSdk.init('');
        expect(BillingSdk.getPayload(), isNull);
      });

      test('init(invalid token) leaves payload null', () {
        BillingSdk.init('not.a.jwt');
        expect(BillingSdk.getPayload(), isNull);
      });

      test('init(valid token) stores payload', () {
        final token = _createCanonicalBillingToken();
        BillingSdk.init(token);
        final payload = BillingSdk.getPayload();
        expect(payload, isNotNull);
        expect(payload!.payingParty.id, 'party_456');
        expect(payload.payingParty.ssoId, 'sso_abc');
        expect(payload.payingParty.billingEmail, 'billing@example.com');
        expect(payload.subscriptionIds, ['sub_canon_1']);
        expect(payload.email, 'billing@example.com');
        expect(payload.hasSubscription('sub_canon_1'), isTrue);
        expect(payload.hasSubscription('sub_99'), isFalse);
        expect(payload.hasPlan('plan_premium'), isTrue);
        expect(payload.hasProduct('prod_1'), isTrue);
      });
    });

    group('verifyAndDecode', () {
      test('empty string returns VerifyFailure malformed', () {
        final result = BillingSdk.verifyAndDecode('');
        expect(result, isA<VerifyFailure>());
        expect((result as VerifyFailure).error.reason,
            BillingTokenErrorReason.malformed);
      });

      test('invalid token returns VerifyFailure', () {
        final result = BillingSdk.verifyAndDecode('invalid');
        expect(result, isA<VerifyFailure>());
      });

      test('valid token returns VerifySuccess and updates getPayload', () {
        final token = _createCanonicalBillingToken();
        final result = BillingSdk.verifyAndDecode(token);
        expect(result, isA<VerifySuccess>());
        final payload = (result as VerifySuccess).payload;
        expect(payload.payingParty.id, 'party_456');
        expect(BillingSdk.getPayload()?.payingParty.id, 'party_456');
      });
    });

    group('syncFromServer', () {
      test('without billingApiBaseUrl throws on sync', () async {
        BillingSdk.resetForTesting();
        expectLater(
          BillingSdk.syncFromServer(authorizationToken: 'Bearer x'),
          throwsStateError,
        );
      });

      test('with empty authorizationToken returns SyncFailure', () async {
        BillingSdk.configure(billingApiBaseUrl: 'https://billing.example.com/');
        final result = await BillingSdk.syncFromServer(authorizationToken: '');
        expect(result, isA<SyncFailure>());
        expect((result as SyncFailure).message, contains('token'));
      });
    });
  });
}
