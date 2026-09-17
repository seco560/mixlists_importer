import 'package:mixlists_importer/src/import/row_mapper.dart';
import 'package:test/test.dart';

// Trimmed down from a real GET /playlists/{id}/items response captured
// live against a Dev Mode app (2026-09-17) -- see the Mixlists Importer
// plan's Phase 3 findings. Deliberately kept close to the real shape
// (flat `item`, boolean `track`/`episode` discriminators, no
// `preview_url`/`popularity` keys at all) rather than an idealized one.
Map<String, Object?> _realisticItemWrapper({
  bool isLocal = false,
  Object? item = _pennywiseTrack,
}) => {
  'added_at': '2026-09-15T18:56:49Z',
  'added_by': {'id': 'secovlad', 'type': 'user'},
  'is_local': isLocal,
  'primary_color': null,
  'item': item,
  'video_thumbnail': {'url': null},
};

const _pennywiseTrack = {
  'is_playable': true,
  'explicit': false,
  'type': 'track',
  'episode': false,
  'track': true,
  'album': {
    'type': 'album',
    'album_type': 'album',
    'id': '2MyjkvQLos52FxpyHJZsfE',
    'images': [
      {'height': 640, 'url': 'https://i.scdn.co/image/large.jpg', 'width': 640},
      {'height': 64, 'url': 'https://i.scdn.co/image/small.jpg', 'width': 64},
    ],
    'name': 'About Time (2005 Remaster)',
    'release_date': '1995-06-13',
    'release_date_precision': 'day',
    'uri': 'spotify:album:2MyjkvQLos52FxpyHJZsfE',
    'artists': [
      {
        'id': '6i0KVTOvm96T55mbp742ks',
        'name': 'Pennywise',
        'type': 'artist',
        'uri': 'spotify:artist:6i0KVTOvm96T55mbp742ks',
      },
    ],
    'total_tracks': 12,
  },
  'artists': [
    {
      'id': '6i0KVTOvm96T55mbp742ks',
      'name': 'Pennywise',
      'type': 'artist',
      'uri': 'spotify:artist:6i0KVTOvm96T55mbp742ks',
    },
  ],
  'disc_number': 1,
  'track_number': 1,
  'duration_ms': 171906,
  'external_ids': {'isrc': 'USEP40419301'},
  'id': '6n7NLrONaFUBHXKQZfYdxH',
  'name': 'Peaceful Day - 2005 Remaster',
  'uri': 'spotify:track:6n7NLrONaFUBHXKQZfYdxH',
  'is_local': false,
};

void main() {
  group('shouldSkipPlaylistItem', () {
    test('false for a normal track item', () {
      expect(shouldSkipPlaylistItem(_realisticItemWrapper()), isFalse);
    });

    test('true for a local file', () {
      expect(
        shouldSkipPlaylistItem(_realisticItemWrapper(isLocal: true)),
        isTrue,
      );
    });

    test('true when item is null (delisted track)', () {
      expect(
        shouldSkipPlaylistItem(_realisticItemWrapper(item: null)),
        isTrue,
      );
    });

    test('true for a podcast episode (track flag false)', () {
      final episode = {..._pennywiseTrack, 'track': false, 'episode': true};
      expect(
        shouldSkipPlaylistItem(_realisticItemWrapper(item: episode)),
        isTrue,
      );
    });
  });

  group('rowFromPlaylistItem', () {
    test('maps every field from a real-shaped response correctly', () {
      final row = rowFromPlaylistItem(
        _realisticItemWrapper(),
        albumArtistGenres: 'punk, skate punk',
      );

      expect(row.trackURI, 'spotify:track:6n7NLrONaFUBHXKQZfYdxH');
      expect(row.trackName, 'Peaceful Day - 2005 Remaster');
      expect(row.artistNames, 'Pennywise');
      expect(row.artistURIs, 'spotify:artist:6i0KVTOvm96T55mbp742ks');
      expect(row.albumName, 'About Time (2005 Remaster)');
      expect(row.albumArtistName, 'Pennywise');
      expect(row.albumArtistURI, 'spotify:artist:6i0KVTOvm96T55mbp742ks');
      expect(row.albumReleaseDate, '1995-06-13');
      expect(row.albumImageURL, 'https://i.scdn.co/image/large.jpg');
      expect(row.discNumber, 1);
      expect(row.albumTrackNumber, 1);
      expect(row.durationMs, 171906);
      expect(row.isExplicit, isFalse);
      expect(row.isrc, 'USEP40419301');
      expect(row.addedAt, '2026-09-15T18:56:49Z');
      expect(row.genres, 'punk, skate punk');

      // Confirmed absent from Dev Mode responses -- must stay null, not
      // silently default to 0/empty-string.
      expect(row.audioPreviewURL, isNull);
      expect(row.popularity, isNull);
      expect(row.recordLabel, isNull);
      expect(row.danceability, isNull);
    });

    test('joins multiple track artists with a comma, unsplit', () {
      final multiArtistTrack = {
        ..._pennywiseTrack,
        'artists': [
          {
            'id': 'a1',
            'name': 'Artist One',
            'uri': 'spotify:artist:a1',
          },
          {
            'id': 'a2',
            'name': 'Artist Two',
            'uri': 'spotify:artist:a2',
          },
        ],
      };
      final row = rowFromPlaylistItem(
        _realisticItemWrapper(item: multiArtistTrack),
        albumArtistGenres: null,
      );
      expect(row.artistNames, 'Artist One, Artist Two');
      expect(row.artistURIs, 'spotify:artist:a1, spotify:artist:a2');
    });

    test('uses only the first album artist when an album has several', () {
      final multiAlbumArtist = {
        ..._pennywiseTrack,
        'album': {
          ..._pennywiseTrack['album'] as Map<String, Object?>,
          'artists': [
            {'id': 'lead', 'name': 'Lead Artist', 'uri': 'spotify:artist:lead'},
            {
              'id': 'feat',
              'name': 'Featured Artist',
              'uri': 'spotify:artist:feat',
            },
          ],
        },
      };
      final row = rowFromPlaylistItem(
        _realisticItemWrapper(item: multiAlbumArtist),
        albumArtistGenres: null,
      );
      expect(row.albumArtistName, 'Lead Artist');
      expect(row.albumArtistURI, 'spotify:artist:lead');
    });

    test('handles a track with no images gracefully', () {
      final noImages = {
        ..._pennywiseTrack,
        'album': {
          ..._pennywiseTrack['album'] as Map<String, Object?>,
          'images': <Object?>[],
        },
      };
      final row = rowFromPlaylistItem(
        _realisticItemWrapper(item: noImages),
        albumArtistGenres: null,
      );
      expect(row.albumImageURL, isNull);
    });

    test('handles a track missing external_ids (no ISRC yet resolved)', () {
      final noExternalIds = {..._pennywiseTrack}..remove('external_ids');
      final row = rowFromPlaylistItem(
        _realisticItemWrapper(item: noExternalIds),
        albumArtistGenres: null,
      );
      expect(row.isrc, isNull);
    });
  });
}
