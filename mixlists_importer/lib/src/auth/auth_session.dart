import 'credential_store.dart';
import 'spotify_auth.dart';

/// Loads a previously-stored login and refreshes it if it's expired,
/// persisting whatever comes back (Spotify may rotate the refresh token
/// on any refresh call, so always overwrite it rather than assuming the
/// original stays valid). Every other command builds on this instead of
/// re-running the interactive login.
class AuthSession {
  AuthSession(this._auth, this._store);

  final SpotifyAuth _auth;
  final CredentialStore _store;

  Future<SpotifyTokens> ensureValidTokens() async {
    final tokens = await _store.read();
    if (tokens == null) {
      throw SpotifyAuthException(
        'Not authenticated yet -- run `mixlists_importer auth` first.',
      );
    }
    if (!tokens.isExpired) return tokens;

    final refreshed = await _auth.refresh(tokens);
    await _store.write(refreshed);
    return refreshed;
  }
}
