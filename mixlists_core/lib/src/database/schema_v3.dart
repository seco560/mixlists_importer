import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Adds the columns/table the "richer" CSV export needs, on top of schema
/// V2. Kept free of Flutter imports so `bin/backfill_new_format_data.dart`
/// (a plain `dart run` script) can use it too.
Future<void> applySchemaV3(Database db) async {
  await db.execute('ALTER TABLE Artists ADD COLUMN genres TEXT');
  await db.execute('ALTER TABLE Albums ADD COLUMN recordLabel TEXT');
  await db.execute('''
    CREATE TABLE SongsAudioFeatures (
      id INTEGER PRIMARY KEY,
      song INTEGER UNIQUE,
      danceability REAL,
      energy REAL,
      key INTEGER,
      loudness REAL,
      mode INTEGER,
      speechiness REAL,
      acousticness REAL,
      instrumentalness REAL,
      liveness REAL,
      valence REAL,
      tempo REAL,
      timeSignature INTEGER,
      FOREIGN KEY(song) REFERENCES Songs(id)
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_audio_features_song ON SongsAudioFeatures(song)',
  );
}
