import 'package:mixlists_core/mixlists_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

MixlistCsvRow _row({
  required String trackURI,
  required String trackName,
  required int durationMs,
  String? isrc,
  String? genres,
  String? recordLabel,
  int? popularity,
  double? danceability,
}) => MixlistCsvRow(
  trackURI: trackURI,
  trackName: trackName,
  artistURIs: null,
  artistNames: 'Some Artist',
  albumURI: null,
  albumName: 'Some Album',
  albumArtistURI: null,
  albumArtistName: 'Some Artist',
  albumReleaseDate: null,
  albumImageURL: null,
  discNumber: null,
  albumTrackNumber: null,
  durationMs: durationMs,
  audioPreviewURL: null,
  isExplicit: false,
  popularity: popularity,
  isrc: isrc,
  addedAt: '2026-01-01T00:00:00Z',
  genres: genres,
  recordLabel: recordLabel,
  danceability: danceability,
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await createSchemaV2(db);
    await applySchemaV3(db);
    await applySchemaV4(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedSong({
    required String spotifyURI,
    required String name,
    required int durationMs,
    String? isrc,
    String? genres,
    String? recordLabel,
    int? popularity,
  }) async {
    final artistId = await db.insert('Artists', {
      'spotifyURI': 'artist-uri-$spotifyURI',
      'name': 'Seed Artist',
      'genres': genres,
    });
    final albumId = await db.insert('Albums', {
      'spotifyURI': 'album-uri-$spotifyURI',
      'name': 'Seed Album',
      'artist': artistId,
      'recordLabel': recordLabel,
    });
    final songId = await db.insert('Songs', {
      'spotifyURI': spotifyURI,
      'name': name,
      'artists': 'Seed Artist',
      'album': albumId,
    });
    await db.insert('SongsExtraData', {
      'durationMs': durationMs,
      'explicit': 'false',
      'popularity': popularity,
      'ISRC': isrc,
      'song': songId,
    });
    return songId;
  }

  test('matches by spotifyURI and backfills null fields only', () async {
    final songId = await seedSong(
      spotifyURI: 'spotify:track:a',
      name: 'Track A',
      durationMs: 200000,
    );

    final supplement = MixlistSupplement(db);
    final summary = await supplement.applyCsvRows([
      _row(
        trackURI: 'spotify:track:a',
        trackName: 'Track A',
        durationMs: 200000,
        genres: 'punk',
        recordLabel: 'Some Label',
        popularity: 42,
        danceability: 0.5,
      ),
    ]);

    expect(summary.matched, 1);
    expect(summary.unmatched, 0);

    final extra = (await db.query(
      'SongsExtraData',
      where: 'song = ?',
      whereArgs: [songId],
    )).first;
    expect(extra['popularity'], 42);

    final features = await db.query(
      'SongsAudioFeatures',
      where: 'song = ?',
      whereArgs: [songId],
    );
    expect(features, hasLength(1));
    expect(features.first['danceability'], 0.5);
  });

  test('does not overwrite already-populated fields', () async {
    final songId = await seedSong(
      spotifyURI: 'spotify:track:b',
      name: 'Track B',
      durationMs: 150000,
      genres: 'existing genre',
      popularity: 10,
    );

    final supplement = MixlistSupplement(db);
    await supplement.applyCsvRows([
      _row(
        trackURI: 'spotify:track:b',
        trackName: 'Track B',
        durationMs: 150000,
        genres: 'new genre should not apply',
        popularity: 99,
      ),
    ]);

    final artistRow = (await db.rawQuery('''
      SELECT a.genres AS genres FROM Artists a
      JOIN Albums al ON al.artist = a.id
      JOIN Songs s ON s.album = al.id
      WHERE s.id = ?
    ''', [songId])).first;
    expect(artistRow['genres'], 'existing genre');

    final extra = (await db.query(
      'SongsExtraData',
      where: 'song = ?',
      whereArgs: [songId],
    )).first;
    expect(extra['popularity'], 10);
  });

  test('falls back to ISRC when spotifyURI does not match', () async {
    final songId = await seedSong(
      spotifyURI: 'spotify:track:old-uri',
      name: 'Track C',
      durationMs: 180000,
      isrc: 'US1234567890',
    );

    final supplement = MixlistSupplement(db);
    final summary = await supplement.applyCsvRows([
      _row(
        trackURI: 'spotify:track:different-uri',
        trackName: 'Track C (different title in this export)',
        durationMs: 999999, // deliberately mismatched duration too
        isrc: 'US1234567890',
        genres: 'matched via isrc',
      ),
    ]);

    expect(summary.matched, 1);
    final artistRow = (await db.rawQuery('''
      SELECT a.genres AS genres FROM Artists a
      JOIN Albums al ON al.artist = a.id
      JOIN Songs s ON s.album = al.id
      WHERE s.id = ?
    ''', [songId])).first;
    expect(artistRow['genres'], 'matched via isrc');
  });

  test('falls back to name+duration within tolerance when no URI/ISRC match', () async {
    await seedSong(
      spotifyURI: 'spotify:track:d',
      name: 'Track D',
      durationMs: 200000,
    );

    final supplement = MixlistSupplement(db);
    final summary = await supplement.applyCsvRows([
      _row(
        trackURI: 'spotify:track:unrelated',
        trackName: 'track d', // case-insensitive match
        durationMs: 200500, // within 1000ms tolerance
        genres: 'matched via name+duration',
      ),
    ]);

    expect(summary.matched, 1);
  });

  test('counts as unmatched when nothing lines up', () async {
    await seedSong(
      spotifyURI: 'spotify:track:e',
      name: 'Track E',
      durationMs: 200000,
    );

    final supplement = MixlistSupplement(db);
    final summary = await supplement.applyCsvRows([
      _row(
        trackURI: 'spotify:track:totally-different',
        trackName: 'Completely Different Track',
        durationMs: 50000,
      ),
    ]);

    expect(summary.matched, 0);
    expect(summary.unmatched, 1);
  });

  test('ambiguous name+duration matches (2+ candidates) are skipped, not guessed', () async {
    await seedSong(
      spotifyURI: 'spotify:track:f1',
      name: 'Duplicate Title',
      durationMs: 200000,
    );
    await seedSong(
      spotifyURI: 'spotify:track:f2',
      name: 'Duplicate Title',
      durationMs: 200200,
    );

    final supplement = MixlistSupplement(db);
    final summary = await supplement.applyCsvRows([
      _row(
        trackURI: 'spotify:track:unrelated-f',
        trackName: 'Duplicate Title',
        durationMs: 200100,
        genres: 'should not be applied to either',
      ),
    ]);

    expect(summary.matched, 0);
    expect(summary.unmatched, 1);
  });

  test('never inserts SongsMixlists rows', () async {
    await seedSong(
      spotifyURI: 'spotify:track:g',
      name: 'Track G',
      durationMs: 200000,
    );

    final supplement = MixlistSupplement(db);
    await supplement.applyCsvRows([
      _row(trackURI: 'spotify:track:g', trackName: 'Track G', durationMs: 200000, genres: 'x'),
    ]);

    final smRows = await db.query('SongsMixlists');
    expect(smRows, isEmpty);
  });

  test('SupplementSummary.mergeWith adds counts from another summary', () {
    final a = SupplementSummary()
      ..matched = 3
      ..unmatched = 1;
    final b = SupplementSummary()
      ..matched = 2
      ..unmatched = 4;
    a.mergeWith(b);
    expect(a.matched, 5);
    expect(a.unmatched, 5);
  });
}
