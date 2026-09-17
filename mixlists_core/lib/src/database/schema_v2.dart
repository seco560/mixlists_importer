import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The original table set: Mixlists, Artists, Albums, Songs,
/// SongsExtraData, SongsMixlists, plus their lookup indexes. Extracted
/// from the Flutter app's `app_database.dart` so both the app and any
/// standalone tool building a fresh db (e.g. the importer) share one
/// definition.
Future<void> createSchemaV2(Database db) async {
  await db.execute('''
    CREATE TABLE Mixlists (
      id INTEGER PRIMARY KEY,
      title TEXT UNIQUE,
      description TEXT,
      dateCreated TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE Artists (
      id INTEGER PRIMARY KEY,
      spotifyURI TEXT,
      name TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE Albums (
      id INTEGER PRIMARY KEY,
      spotifyURI TEXT,
      name TEXT,
      releaseDate TEXT,
      coverImageURL TEXT,
      artist INTEGER,
      FOREIGN KEY(artist) REFERENCES Artists(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE Songs (
      id INTEGER PRIMARY KEY,
      spotifyURI TEXT,
      name TEXT,
      artists TEXT,
      artistsURIs TEXT,
      album INTEGER,
      FOREIGN KEY(album) REFERENCES Albums(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE SongsExtraData (
      id INTEGER PRIMARY KEY,
      discNumber INT,
      albumTrackNumber INT,
      durationMs INT,
      audioPreviewURL TEXT,
      explicit TEXT,
      popularity INT,
      ISRC TEXT,
      song INTEGER,
      FOREIGN KEY(song) REFERENCES Songs(id)
    )
  ''');
  await db.execute('''
    CREATE TABLE SongsMixlists (
      id INTEGER PRIMARY KEY,
      positionIndex INT,
      dateAdded TEXT,
      song INTEGER,
      mixlist INTEGER,
      FOREIGN KEY(song) REFERENCES Songs(id),
      FOREIGN KEY(mixlist) REFERENCES Mixlists(id)
    )
  ''');
  await db.execute('CREATE INDEX idx_albums_artist ON Albums(artist)');
  await db.execute('CREATE INDEX idx_songs_album ON Songs(album)');
  await db.execute('CREATE INDEX idx_extra_song ON SongsExtraData(song)');
  await db.execute('CREATE INDEX idx_sm_mixlist ON SongsMixlists(mixlist)');
  await db.execute('CREATE INDEX idx_sm_song ON SongsMixlists(song)');
}

/// The five lookup indexes, applied defensively on upgrade for a db whose
/// v1 schema shipped without them.
Future<void> createSchemaV2Indexes(Database db) async {
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_albums_artist ON Albums(artist)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_songs_album ON Songs(album)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_extra_song ON SongsExtraData(song)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_sm_mixlist ON SongsMixlists(mixlist)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_sm_song ON SongsMixlists(song)',
  );
}
