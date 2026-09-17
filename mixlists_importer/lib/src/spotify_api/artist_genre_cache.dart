import 'spotify_client.dart';

/// Resolves and caches an artist's genres (joined the same way the CSV
/// pipeline already stores them, comma-separated) for the lifetime of a
/// run. `genres` isn't present on the simplified artist objects embedded
/// in track/album responses, so this is the one per-item API call the
/// importer still needs -- caching means a prolific artist appearing
/// across dozens of playlists costs exactly one call, not one per track.
class ArtistGenreCache {
  ArtistGenreCache(this._client);

  final SpotifyClient _client;
  final Map<String, String?> _cache = {};

  Future<String?> genresFor(String artistId) async {
    if (_cache.containsKey(artistId)) return _cache[artistId];
    final json = await _client.getJson(
      Uri.parse('https://api.spotify.com/v1/artists/$artistId'),
    );
    final genres = (json['genres'] as List?)?.cast<String>() ?? const [];
    final joined = genres.isEmpty ? null : genres.join(', ');
    _cache[artistId] = joined;
    return joined;
  }
}
