/// Shared, Flutter-free core for the Mixlists project: the sqlite schema,
/// entity classes, the CSV row parser, and the get-or-create ingestion
/// logic. Used by both the Flutter app (via a `path:` dependency) and the
/// `mixlists_importer` CLI, so schema/dedup logic has one source of truth.
library;

export 'src/database/schema_v2.dart';
export 'src/database/schema_v3.dart';
export 'src/database/schema_v4.dart';

export 'src/entities/album.dart';
export 'src/entities/artist.dart';
export 'src/entities/mixlist.dart';
export 'src/entities/song.dart';
export 'src/entities/song_audio_features.dart';
export 'src/entities/song_extra_data.dart';
export 'src/entities/song_mixlist.dart';

export 'src/csv/mixlist_csv_parser.dart';

export 'src/repository/mixlist_ingestion.dart';
