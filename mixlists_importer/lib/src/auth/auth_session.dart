import 'credential_store.dart';
import 'spotify_auth.dart';

/// Loads a previously-stored login and refreshes it if it's expired,
/// persisting whatever comes back (Spotify may rotate the refresh token
/// on any refresh call, so always overwrite it rather than assuming the
/// original stays valid). Every other command builds on this instead of
/// re-running the interactive login.
///
/// Deliberately doesn't require a Client ID up front: the stored tokens
/// already carry the Client ID they were issued under, so a valid,
/// unexpired login needs no Client ID at all, and an expired one falls
/// back to the stored value unless [clientIdOverride] is given.
class AuthSession {
  AuthSession(this._store, {String? clientIdOverride})
    : _clientIdOverride = clientIdOverride;

  final CredentialStore _store;
  final String? _clientIdOverride;

  Future<SpotifyTokens> ensureValidTokens() async {
    final tokens = await _readStoredTokens();
    if (!tokens.isExpired) return tokens;
    return _refresh(tokens);
  }

  /// Refreshes unconditionally, ignoring the local expiry clock -- for
  /// when the server itself rejects a token we thought was still good
  /// (clock skew, or Spotify revoked it early).
  Future<SpotifyTokens> forceRefresh() async {
    final tokens = await _readStoredTokens();
    return _refresh(tokens);
  }

  Future<SpotifyTokens> _readStoredTokens() async {
    final tokens = await _store.read();
    if (tokens == null) {
      throw SpotifyAuthException(
        'Not authenticated yet -- run `mixlists_importer auth` first.',
      );
    }
    return tokens;
  }

  Future<SpotifyTokens> _refresh(SpotifyTokens tokens) async {
    final auth = SpotifyAuth(clientId: _clientIdOverride ?? tokens.clientId);
    final refreshed = await auth.refresh(tokens);
    await _store.write(refreshed);
    return refreshed;
  }
}
