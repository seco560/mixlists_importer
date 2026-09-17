import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import '../auth/auth_session.dart';

class SpotifyApiException implements Exception {
  SpotifyApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() =>
      'Spotify API error${statusCode != null ? ' ($statusCode)' : ''}: $message';
}

/// Thin wrapper around the Spotify Web API: attaches the bearer token,
/// force-refreshes once on an unexpected 401, retries on 429 (honoring
/// `Retry-After`) and 5xx with backoff, and paces every request by a
/// small fixed delay. There's no published fixed rate limit for Dev Mode
/// apps (just an undisclosed rolling 30s window), so pacing conservatively
/// by default is deliberate, not a guess -- see the Mixlists Importer
/// plan's pitfalls list.
class SpotifyClient {
  SpotifyClient(
    this._session, {
    this.requestDelay = const Duration(milliseconds: 100),
    this.maxRetries = 5,
  });

  final AuthSession _session;
  final Duration requestDelay;
  final int maxRetries;

  Future<Map<String, Object?>> getJson(Uri url) async {
    var tokens = await _session.ensureValidTokens();
    var forcedRefresh = false;
    var retries = 0;

    while (true) {
      await Future.delayed(requestDelay);
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer ${tokens.accessToken}'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, Object?>;
      }

      // Our local expiry clock said the token was still good, but the
      // server disagrees (clock skew, or Spotify revoked it early) --
      // force one hard refresh and retry, but only once.
      if (response.statusCode == 401 && !forcedRefresh) {
        forcedRefresh = true;
        tokens = await _session.forceRefresh();
        continue;
      }

      if (response.statusCode == 429) {
        retries++;
        if (retries > maxRetries) {
          throw SpotifyApiException(
            'Rate limited $maxRetries times in a row -- giving up.',
            statusCode: 429,
          );
        }
        final retryAfterSeconds =
            int.tryParse(response.headers['retry-after'] ?? '') ?? 1;
        await Future.delayed(
          Duration(seconds: retryAfterSeconds) +
              Duration(milliseconds: Random().nextInt(300)),
        );
        continue;
      }

      if (response.statusCode >= 500) {
        retries++;
        if (retries > maxRetries) {
          throw SpotifyApiException(
            'Server error after $maxRetries attempts: ${response.body}',
            statusCode: response.statusCode,
          );
        }
        await Future.delayed(Duration(seconds: min(30, 1 << retries)));
        continue;
      }

      throw SpotifyApiException(response.body, statusCode: response.statusCode);
    }
  }
}
