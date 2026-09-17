import 'package:mixlists_core/mixlists_core.dart';

/// True if this entry from `/playlists/{id}/items` should be skipped:
/// a local file with no real Spotify track behind it, a delisted track
/// (null `item`), or a podcast episode (`additional_types` defaults to
/// `track` only, but check anyway rather than assume the API respects
/// that in every case).
bool shouldSkipPlaylistItem(Map<String, Object?> wrapper) {
  if (wrapper['is_local'] == true) return true;
  final item = wrapper['item'] as Map<String, Object?>?;
  if (item == null) return true;
  return item['track'] != true;
}

/// Builds a [MixlistCsvRow] directly from one raw JSON entry of
/// `/playlists/{id}/items`'s `items[]`, plus the resolved genre string
/// for the album's primary artist (or null if unavailable). The field
/// choices here are pinned to a real, live-verified response shape (see
/// the Mixlists Importer plan's Phase 3 findings) -- notably `item` is
/// flat (track fields sit directly on it, not wrapped), and
/// `preview_url`/`popularity`/`label` are confirmed absent entirely for
/// this Dev Mode app, not just unreliable.
///
/// `Albums.artist` is a single FK, but `album.artists` can list more
/// than one. Rather than replicating the old CSV pipeline's comma-join
/// workaround for that (a hack that only existed because CSV exports
/// gave no structured artist list), this just takes the first credited
/// album artist as canonical -- we now have a real artist id/uri to key
/// on, so there's no reason to keep the workaround around.
MixlistCsvRow rowFromPlaylistItem(
  Map<String, Object?> wrapper, {
  required String? albumArtistGenres,
}) {
  final item = wrapper['item'] as Map<String, Object?>;
  final artists = (item['artists'] as List).cast<Map<String, Object?>>();
  final album = item['album'] as Map<String, Object?>;
  final albumArtists = (album['artists'] as List).cast<Map<String, Object?>>();
  final albumArtist = albumArtists.first;
  final images = (album['images'] as List).cast<Map<String, Object?>>();
  final externalIds = item['external_ids'] as Map<String, Object?>?;

  return MixlistCsvRow(
    trackURI: item['uri'] as String,
    trackName: item['name'] as String,
    artistURIs: artists.map((a) => a['uri'] as String).join(', '),
    artistNames: artists.map((a) => a['name'] as String).join(', '),
    albumURI: album['uri'] as String?,
    albumName: album['name'] as String,
    albumArtistURI: albumArtist['uri'] as String?,
    albumArtistName: albumArtist['name'] as String,
    albumReleaseDate: album['release_date'] as String?,
    albumImageURL: images.isNotEmpty ? images.first['url'] as String? : null,
    discNumber: item['disc_number'] as int?,
    albumTrackNumber: item['track_number'] as int?,
    durationMs: item['duration_ms'] as int,
    audioPreviewURL: null, // confirmed absent from Dev Mode responses
    isExplicit: item['explicit'] as bool? ?? false,
    popularity: null, // removed from the API for Dev Mode apps
    isrc: externalIds?['isrc'] as String?,
    addedAt: wrapper['added_at'] as String,
    genres: albumArtistGenres,
    recordLabel: null, // removed from the API for Dev Mode apps; supplement-step only
    danceability: null,
    energy: null,
    key: null,
    loudness: null,
    mode: null,
    speechiness: null,
    acousticness: null,
    instrumentalness: null,
    liveness: null,
    valence: null,
    tempo: null,
    timeSignature: null,
  );
}
