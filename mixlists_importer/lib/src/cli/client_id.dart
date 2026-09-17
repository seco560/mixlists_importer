import 'dart:io';

/// Resolves the Spotify Client ID from `--client-id` if given, else the
/// `SPOTIFY_CLIENT_ID` env var. Returns null (caller should print an
/// error and exit) if neither is set. Never hardcoded -- this is a
/// personal app's Client ID, not a secret, but there's no reason to bake
/// it into source either.
String? resolveClientId(String? fromFlag) {
  final value = fromFlag ?? Platform.environment['SPOTIFY_CLIENT_ID'];
  return (value == null || value.isEmpty) ? null : value;
}

const clientIdMissingMessage =
    'No Spotify Client ID given. Pass --client-id, or set the '
    'SPOTIFY_CLIENT_ID environment variable, to the Client ID from your '
    "app's page at https://developer.spotify.com/dashboard.";
