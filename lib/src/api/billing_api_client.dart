import 'dart:convert';

import 'package:http/http.dart' as http;

/// Result of syncing from the Billing API.
sealed class SyncResult {}

class SyncSuccess implements SyncResult {
  const SyncSuccess({required this.signedToken});
  final String signedToken;
}

class SyncFailure implements SyncResult {
  const SyncFailure({required this.message});
  final String message;
}

/// HTTP client for the Billing API (sync and optional public-key fetch).
class BillingApiClient {
  BillingApiClient({required String baseUrl})
    : _baseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';

  final String _baseUrl;

  /// GET /api/billing/license with Authorization header.
  /// [authorizationToken] is required (Bearer or SSO token). No query params.
  /// Response: map with key `signedToken` (JWT string), possibly under `data`. Returns [SyncSuccess] or [SyncFailure].
  Future<SyncResult> fetchLicense({required String authorizationToken}) async {
    final raw = authorizationToken.trim();
    if (raw.isEmpty) {
      return const SyncFailure(message: 'Authorization token is required.');
    }
    final token = raw.toLowerCase().startsWith('bearer ') ? raw : 'Bearer $raw';
    final uri = Uri.parse('${_baseUrl}api/billing/license');
    final headers = <String, String>{'Authorization': token};

    try {
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>?;

        final rawData = body?['data'];
        final data = rawData is Map<String, dynamic> ? rawData : body;
        final signed = data?['signedToken'] ?? data?['signed_token'] ?? data?['token'];

        if (signed is String && signed.isNotEmpty) {
          return SyncSuccess(signedToken: signed);
        }

        return const SyncFailure(
          message: 'Sync failed. Invalid response from server.',
        );
      }

      if (response.statusCode == 400) {
        return const SyncFailure(message: 'Bad request. Check your token.');
      }

      if (response.statusCode == 401) {
        return const SyncFailure(
          message: 'Session expired or invalid. Please sign in again.',
        );
      }

      if (response.statusCode == 404) {
        return const SyncFailure(
          message: 'No billing account found for this user.',
        );
      }

      return const SyncFailure(message: 'Sync failed. Try again later.');
    } catch (_) {
      return const SyncFailure(message: 'Sync failed. Try again later.');
    }
  }
}
