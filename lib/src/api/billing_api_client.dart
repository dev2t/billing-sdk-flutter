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

  /// GET /api/billing/license?email=... or ?ssoId=...
  /// Protected endpoint: pass [authorizationToken] (e.g. Bearer/ssoToken) to authenticate.
  /// Response: map with key `signedToken` (JWT string). Returns [SyncSuccess] or [SyncFailure].
  Future<SyncResult> fetchSdkToken({
    String? email,
    String? ssoId,
    String? authorizationToken,
  }) async {
    if ((email == null || email.isEmpty) && (ssoId == null || ssoId.isEmpty)) {
      return const SyncFailure(message: 'Missing user identifier.');
    }

    if (email != null &&
        email.isNotEmpty &&
        ssoId != null &&
        ssoId.isNotEmpty) {
      return const SyncFailure(
        message: 'Provide either email or ssoId, not both.',
      );
    }

    final query = email != null && email.isNotEmpty
        ? 'email=${Uri.encodeComponent(email)}'
        : 'ssoId=${Uri.encodeComponent(ssoId!)}';

    final uri = Uri.parse('${_baseUrl}api/billing/license?$query');

    final headers = <String, String>{};
    if (authorizationToken != null && authorizationToken.trim().isNotEmpty) {
      final token = authorizationToken.trim();
      headers['Authorization'] = token.toLowerCase().startsWith('bearer ')
          ? token
          : 'Bearer $token';
    }

    try {
      final response = await http.get(
        uri,
        headers: headers.isEmpty ? null : headers,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>?;

        final rawData = body?['data'];
        final data = rawData is Map<String, dynamic> ? rawData : body;
        final token = data?['signedToken'];

        if (token is String && token.isNotEmpty) {
          return SyncSuccess(signedToken: token);
        }

        return const SyncFailure(
          message: 'Sync failed. Invalid response from server.',
        );
      }

      if (response.statusCode == 400) {
        return const SyncFailure(message: 'Missing user identifier.');
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
