import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Adds `Mixlists.is_mixlists` (0/1): whether the user has marked this
/// playlist as one of their curated "mixlists" rather than just any
/// Spotify playlist that got pulled in by a bulk import. Defaults to 0
/// (unmarked) for every existing row -- nothing is a mixlist until the
/// user says so via the "Mark Mixlists" screen.
Future<void> applySchemaV5(Database db) async {
  await db.execute(
    'ALTER TABLE Mixlists ADD COLUMN is_mixlists INTEGER NOT NULL DEFAULT 0',
  );
}
