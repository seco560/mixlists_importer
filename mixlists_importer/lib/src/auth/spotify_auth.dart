import 'dart:convert';
import 'package:http/http.dart' as http;

import 'loopback_server.dart';
import 'pkce.dart';

const _authorizeEndpoint = 'https://accounts.spotify.com/authorize';
const _tokenEndpoint = 'https://accounts.spotify.com/api/token';
const _mePath = 'https://api.spotify.com/v1/me';

/// Read-only scopes needed to list and read the user's own playlists
/// (including private and collaborative ones) -- nothing that can modify
/// the account.
const defaultSpotifyScopes = [
  'playlist-read-private',
  'playlist-read-collaborative',
];

class SpotifyAuthException implements Exception {
  SpotifyAuthException(this.message);
  final String message;
  @override
  String toString() => 'Spotify auth error: $message';
}

/// An access/refresh token pair, plus the Client ID they were issued
/// under -- storing it means later commands (`whoami`, `run`, ...) don't
/// have to ask for `--client-id` again just to refresh an already-valid
/// login. No client secret is ever involved -- PKCE is a public-client
/// flow.
class SpotifyTokens {
  const SpotifyTokens({
    required this.clientId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.scope,
  });

  final String clientId;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String scope;

  /// True if the token is expired or expiring within the next 30s --
  /// refresh proactively rather than racing a request against expiry.
  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));

  Map<String, Object?> toJson() => {
    'clientId': clientId,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'scope': scope,
  };

  factory SpotifyTokens.fromJson(Map<String, Object?> json) {
    final clientId = json['clientId'] as String?;
    if (clientId == null) {
      throw SpotifyAuthException(
        'Stored credentials are from an older format that did not save the '
        'Client ID -- run `mixlists_importer auth` again.',
      );
    }
    return SpotifyTokens(
      clientId: clientId,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      scope: json['scope'] as String,
    );
  }
}

/// Drives the Authorization Code + PKCE flow against a loopback redirect,
/// and refreshes tokens afterward. See the Mixlists Importer plan for why
/// PKCE (no client secret) and a loopback IP literal (not `localhost`)
/// are both hard requirements from Spotify's side, not just choices.
class SpotifyAuth {
  SpotifyAuth({
    required this.clientId,
    this.port = 43847,
    this.scopes = defaultSpotifyScopes,
  });

  final String clientId;
  final int port;
  final List<String> scopes;

  Uri get redirectUri => Uri.parse('http://127.0.0.1:$port/callback');

  /// Runs the full interactive login: starts the loopback server, hands
  /// the caller the URL to open (so the CLI layer decides how/whether to
  /// auto-open a browser), waits for the redirect, then exchanges the
  /// code for tokens.
  Future<SpotifyTokens> login({
    required void Function(Uri authorizeUrl) onReadyToAuthorize,
  }) async {
    final pkce = PkcePair.generate();
    final state = randomUrlSafeToken(16);
    final server = LoopbackServer(port: port);

    final authorizeUrl = Uri.parse(_authorizeEndpoint).replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri.toString(),
        'code_challenge_method': 'S256',
        'code_challenge': pkce.challenge,
        'scope': scopes.join(' '),
        'state': state,
      },
    );

    final resultFuture = server.waitForCallback();
    onReadyToAuthorize(authorizeUrl);

    final AuthorizationResult result;
    try {
      result = await resultFuture;
    } finally {
      await server.close();
    }

    if (result.error != null) {
      throw SpotifyAuthException('Spotify returned an error: ${result.error}');
    }
    if (result.state != state) {
      throw SpotifyAuthException(
        'OAuth state mismatch (possible CSRF) -- aborting without exchanging '
        'the code.',
      );
    }
    final code = result.code;
    if (code == null) {
      throw SpotifyAuthException('No authorization code received.');
    }

    return _exchangeCode(code: code, verifier: pkce.verifier);
  }

  Future<SpotifyTokens> _exchangeCode({
    required String code,
    required String verifier,
  }) {
    return _requestTokens({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri.toString(),
      'client_id': clientId,
      'code_verifier': verifier,
    }, previousRefreshToken: null);
  }

  /// Spotify may or may not rotate the refresh token on a refresh call;
  /// when it doesn't send a new one, keep using the one we already have.
  Future<SpotifyTokens> refresh(SpotifyTokens tokens) {
    return _requestTokens({
      'grant_type': 'refresh_token',
      'refresh_token': tokens.refreshToken,
      'client_id': clientId,
    }, previousRefreshToken: tokens.refreshToken);
  }

  Future<SpotifyTokens> _requestTokens(
    Map<String, String> body, {
    required String? previousRefreshToken,
  }) async {
    final response = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (response.statusCode != 200) {
      throw SpotifyAuthException(
        'Token request failed (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, Object?>;
    final refreshToken = (json['refresh_token'] as String?) ?? previousRefreshToken;
    if (refreshToken == null) {
      throw SpotifyAuthException(
        'No refresh token in the response and none to fall back to.',
      );
    }

    return SpotifyTokens(
      clientId: clientId,
      accessToken: json['access_token'] as String,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(
        Duration(seconds: json['expires_in'] as int),
      ),
      scope: (json['scope'] as String?) ?? scopes.join(' '),
    );
  }
}

/// A minimal call to confirm a token actually works and report who's
/// authenticated -- used by `auth`/`whoami`, not part of the main
/// playlist-fetching path. Free function, not a `SpotifyAuth` method,
/// since GET /me needs only a bearer token -- no Client ID involved.
Future<String> fetchCurrentUserDisplayName(String accessToken) async {
  final response = await http.get(
    Uri.parse(_mePath),
    headers: {'Authorization': 'Bearer $accessToken'},
  );
  if (response.statusCode != 200) {
    throw SpotifyAuthException(
      'GET /me failed (${response.statusCode}): ${response.body}',
    );
  }
  final json = jsonDecode(response.body) as Map<String, Object?>;
  return (json['display_name'] as String?) ?? (json['id'] as String);
}
