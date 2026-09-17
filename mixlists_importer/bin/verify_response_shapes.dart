// Throwaway-turned-diagnostic script: dumps one raw page each from
// /me/playlists and /playlists/{id}/items against your REAL, already
// logged-in account (run `auth` first). The point is to confirm actual
// field names/nesting/nullability in Dev Mode before writing any
// playlist-import mapping code -- Spotify's own reference docs are known
// to drift from what Dev Mode responses actually contain (e.g. fields
// like `popularity` documented as present but stripped in practice).
//
// Usage: dart run bin/verify_response_shapes.dart [--playlist-id <id>]
//
// Without --playlist-id, inspects the first playlist returned by
// /me/playlists. Prints pretty-printed JSON to stdout -- pipe to a file
// or `less` if it's long.

import 'dart:convert';
import 'dart:io';

import 'package:mixlists_importer/src/auth/auth_session.dart';
import 'package:mixlists_importer/src/auth/credential_store.dart';
import 'package:mixlists_importer/src/spotify_api/spotify_client.dart';

const _encoder = JsonEncoder.withIndent('  ');

Future<void> main(List<String> arguments) async {
  String? explicitPlaylistId;
  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--playlist-id' && i + 1 < arguments.length) {
      explicitPlaylistId = arguments[++i];
    }
  }

  final client = SpotifyClient(AuthSession(CredentialStore()));

  print('=== GET /me/playlists (first page, limit=5) ===');
  final playlistsPage = await client.getJson(
    Uri.parse('https://api.spotify.com/v1/me/playlists?limit=5'),
  );
  print(_encoder.convert(playlistsPage));

  final playlistItems = (playlistsPage['items'] as List)
      .cast<Map<String, Object?>>();

  final String playlistId;
  if (explicitPlaylistId != null) {
    playlistId = explicitPlaylistId;
  } else if (playlistItems.isNotEmpty) {
    playlistId = playlistItems.first['id'] as String;
  } else {
    stderr.writeln(
      '\nNo playlists on this page and no --playlist-id given -- nothing '
      'to inspect for /items.',
    );
    return;
  }

  print('\n=== GET /playlists/$playlistId/items (first page, limit=3) ===');
  final itemsPage = await client.getJson(
    Uri.parse(
      'https://api.spotify.com/v1/playlists/$playlistId/items?limit=3',
    ),
  );
  print(_encoder.convert(itemsPage));
}
