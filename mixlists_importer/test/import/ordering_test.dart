import 'package:mixlists_core/mixlists_core.dart';
import 'package:mixlists_importer/src/import/ordering.dart';
import 'package:mixlists_importer/src/spotify_api/playlists.dart';
import 'package:test/test.dart';

MixlistCsvRow _rowAddedAt(String addedAt) => MixlistCsvRow(
  trackURI: 'spotify:track:x',
  trackName: 'Track',
  artistURIs: null,
  artistNames: 'Artist',
  albumURI: null,
  albumName: 'Album',
  albumArtistURI: null,
  albumArtistName: 'Artist',
  albumReleaseDate: null,
  albumImageURL: null,
  discNumber: null,
  albumTrackNumber: null,
  durationMs: 1000,
  audioPreviewURL: null,
  isExplicit: false,
  popularity: null,
  isrc: null,
  addedAt: addedAt,
  genres: null,
  recordLabel: null,
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

PlaylistImportBatch _batch(String name, List<String> addedAts) => PlaylistImportBatch(
  playlist: SpotifyPlaylistSummary(
    id: name,
    name: name,
    description: '',
    ownerId: 'me',
    collaborative: false,
  ),
  rows: addedAts.map(_rowAddedAt).toList(),
);

void main() {
  group('PlaylistImportBatch.earliestAddedAt', () {
    test('is the minimum addedAt across all rows, not just the first', () {
      final batch = _batch('Mix', [
        '2026-03-01T00:00:00Z',
        '2025-01-01T00:00:00Z',
        '2026-06-01T00:00:00Z',
      ]);
      expect(batch.earliestAddedAt, '2025-01-01T00:00:00Z');
    });
  });

  group('sortByEarliestAddedAt', () {
    test('sorts playlists ascending by their earliest track addedAt', () {
      final newer = _batch('Newer', ['2026-06-01T00:00:00Z']);
      final older = _batch('Older', ['2020-01-01T00:00:00Z']);
      final middle = _batch('Middle', ['2023-01-01T00:00:00Z']);

      final sorted = sortByEarliestAddedAt([newer, older, middle]);

      expect(sorted.map((b) => b.playlist.name).toList(), [
        'Older',
        'Middle',
        'Newer',
      ]);
    });

    test('does not mutate the input list', () {
      final a = _batch('A', ['2026-01-01T00:00:00Z']);
      final b = _batch('B', ['2020-01-01T00:00:00Z']);
      final input = [a, b];

      sortByEarliestAddedAt(input);

      expect(input, [a, b]);
    });
  });
}
