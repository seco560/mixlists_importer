import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../csv/mixlist_csv_parser.dart';
import 'mixlist_ingestion.dart';

/// Counts from one [MixlistSupplement.applyCsvRows] call.
class SupplementSummary {
  int matched = 0;
  int unmatched = 0;

  void mergeWith(SupplementSummary other) {
    matched += other.matched;
    unmatched += other.unmatched;
  }
}

/// Backfills genres/record-label/popularity/audio-features from CSV rows
/// (e.g. an Exportify export) onto songs that already exist in the db --
/// generalized from the Flutter app's `bin/backfill_new_format_data.dart`
/// script. Exists because the Spotify Web API no longer provides these
/// four fields to personal (non-Extended-Quota) apps at all, so an
/// API-based importer still needs an occasional CSV-sourced top-up path
/// for them.
///
/// Unlike the original backfill script, matching here is library-wide
/// rather than scoped to one already-identified mixlist: every song the
/// API importer writes already carries a real `spotifyURI`, so most rows
/// resolve on the first match tier. This never touches `SongsMixlists`
/// or inserts new songs/mixlists -- rows that don't match an existing
/// song are just skipped and counted, not inserted.
class MixlistSupplement {
  MixlistSupplement(this._db) : _ingestion = MixlistIngestion(_db);

  final Database _db;
  final MixlistIngestion _ingestion;

  /// Applies every row from one CSV file's worth of [rows] in a single
  /// transaction (one file = one atomic unit, matching the ingestion
  /// side's per-mixlist transaction granularity).
  Future<SupplementSummary> applyCsvRows(List<MixlistCsvRow> rows) async {
    final summary = SupplementSummary();
    await _db.transaction((txn) async {
      for (final row in rows) {
        final songId = await _findMatchingSongId(txn, row);
        if (songId == null) {
          summary.unmatched++;
          continue;
        }
        await _backfillSong(txn, songId, row);
        summary.matched++;
      }
    });
    return summary;
  }

  /// Matches by `spotifyURI` first, then ISRC, then library-wide
  /// `(name, durationMs ±1000ms)` -- the same fallback chain
  /// [MixlistIngestion.getOrCreateSongId] uses for CSV ingestion, minus
  /// the "insert if nothing matches" tail, since supplementing never
  /// creates new songs. Zero or multiple candidates at any tier means
  /// skip, not guess -- same accepted-limitation posture as the rest of
  /// this matching logic.
  Future<int?> _findMatchingSongId(
    DatabaseExecutor txn,
    MixlistCsvRow row,
  ) async {
    final byUri = await txn.query(
      'Songs',
      columns: ['id'],
      where: 'spotifyURI = ?',
      whereArgs: [row.trackURI],
    );
    if (byUri.length == 1) return byUri.first['id'] as int;
    if (byUri.isNotEmpty) return null;

    final isrc = row.isrc;
    if (isrc != null) {
      final byIsrc = await txn.rawQuery(
        '''
        SELECT s.id AS id FROM Songs s
        JOIN SongsExtraData ed ON ed.song = s.id
        WHERE ed.ISRC = ?
        ''',
        [isrc],
      );
      if (byIsrc.length == 1) return byIsrc.first['id'] as int;
      if (byIsrc.isNotEmpty) return null;
    }

    // Re-masters can shift reported duration by ~100ms; 1000ms tolerance
    // covers that without matching a genuinely different version -- same
    // tolerance as the ingestion side.
    const toleranceMs = 1000;
    final candidates = await txn.rawQuery(
      '''
      SELECT s.id AS id, s.name AS name FROM Songs s
      JOIN SongsExtraData ed ON ed.song = s.id
      WHERE ed.durationMs BETWEEN ? AND ?
      ''',
      [row.durationMs - toleranceMs, row.durationMs + toleranceMs],
    );
    final normalizedName = row.trackName.trim().toLowerCase();
    final nameMatches = candidates.where(
      (c) => (c['name'] as String).trim().toLowerCase() == normalizedName,
    );
    if (nameMatches.length == 1) return nameMatches.first['id'] as int;
    return null;
  }

  /// Backfills only currently-null fields on the matched song's Artist
  /// and Album rows, plus `SongsExtraData.popularity`, and inserts
  /// `SongsAudioFeatures` only if absent -- never overwrites data that's
  /// already there.
  Future<void> _backfillSong(
    DatabaseExecutor txn,
    int songId,
    MixlistCsvRow row,
  ) async {
    final songRows = await txn.query(
      'Songs',
      columns: ['album'],
      where: 'id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    final albumId = songRows.first['album'] as int;
    final albumRows = await txn.query(
      'Albums',
      columns: ['artist'],
      where: 'id = ?',
      whereArgs: [albumId],
      limit: 1,
    );
    final artistId = albumRows.first['artist'] as int;

    if (row.genres != null) {
      await txn.update(
        'Artists',
        {'genres': row.genres},
        where: 'id = ? AND genres IS NULL',
        whereArgs: [artistId],
      );
    }
    if (row.recordLabel != null) {
      await txn.update(
        'Albums',
        {'recordLabel': row.recordLabel},
        where: 'id = ? AND recordLabel IS NULL',
        whereArgs: [albumId],
      );
    }
    if (row.popularity != null) {
      await txn.update(
        'SongsExtraData',
        {'popularity': row.popularity},
        where: 'song = ? AND popularity IS NULL',
        whereArgs: [songId],
      );
    }
    await _ingestion.upsertSongAudioFeatures(txn, songId: songId, row: row);
  }
}
