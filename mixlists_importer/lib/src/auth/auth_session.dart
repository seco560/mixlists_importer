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
    final tokens = await _store.read();
    if (tokens == null) {
      throw SpotifyAuthException(
        'Not authenticated yet -- run `mixlists_importer auth` first.',
      );
    }
    if (!tokens.isExpired) return tokens;

    final auth = SpotifyAuth(clientId: _clientIdOverride ?? tokens.clientId);
    final refreshed = await auth.refresh(tokens);
    await _store.write(refreshed);
    return refreshed;
  }
}
