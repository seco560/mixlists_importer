import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Partial unique indexes on the three `spotifyURI` columns, scoped to
/// `WHERE spotifyURI IS NOT NULL` so legacy/local rows without one stay
/// unconstrained. Once the importer guarantees a real spotifyURI on every
/// row it writes, this is the dominant lookup key used by the get-or-create
/// matching in `MixlistIngestion`, and was previously unindexed.
///
/// Each index is created independently and failures are swallowed with a
/// warning rather than aborting the migration: known pre-existing data
/// quality issues (duplicate Artist rows from ambiguous name-based
/// matching, orphaned rows from earlier ingestion bugs) can leave a live
/// database with duplicate non-null spotifyURI values, which would make
/// `CREATE UNIQUE INDEX` fail. A freshly-built db (e.g. from the importer)
/// won't hit this; an existing app db might, until those duplicates are
/// cleaned up separately.
Future<void> applySchemaV4(Database db) async {
  await _tryCreateUniqueIndex(
    db,
    'idx_artists_spotify_uri',
    'Artists',
    'spotifyURI',
  );
  await _tryCreateUniqueIndex(
    db,
    'idx_albums_spotify_uri',
    'Albums',
    'spotifyURI',
  );
  await _tryCreateUniqueIndex(
    db,
    'idx_songs_spotify_uri',
    'Songs',
    'spotifyURI',
  );
}

Future<void> _tryCreateUniqueIndex(
  Database db,
  String indexName,
  String table,
  String column,
) async {
  try {
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS $indexName ON $table($column) '
      'WHERE $column IS NOT NULL',
    );
  } on DatabaseException catch (e) {
    // ignore: avoid_print
    print(
      'Warning: could not create $indexName ($table.$column has duplicate '
      'non-null values) -- skipping. $e',
    );
  }
}
