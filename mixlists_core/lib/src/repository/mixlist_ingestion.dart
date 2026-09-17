import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../csv/mixlist_csv_parser.dart';
import '../entities/song_extra_data.dart';

/// Thrown by [MixlistIngestion.importMixlistFromCsvRows] when `title`
/// already names an existing Mixlists row.
class MixlistTitleExistsException implements Exception {
  final String title;
  const MixlistTitleExistsException(this.title);
  @override
  String toString() => "A mixlist named '$title' already exists";
}

/// Write path for importing a mixlist from [MixlistCsvRow]s (whether
/// parsed from an actual CSV file or built directly from Spotify API
/// objects -- the row shape doesn't care which). The get-or-create helpers
/// are generic (keyed by spotifyURI) so any tool writing into this schema
/// can reuse them: the Flutter app's "Add New Mixlist" screen, a one-time
/// backfill script, and the Spotify API importer all go through this one
/// class.
class MixlistIngestion {
  MixlistIngestion(this._db);

  final Database _db;

  /// Case/whitespace-insensitive title match, done in Dart -- sqlite's
  /// `lower()` is ASCII-only and misses non-ASCII casing (e.g. 'Ș').
  Future<bool> mixlistTitleExists(String title) async {
    final normalized = title.trim().toLowerCase();
    final rows = await _db.query('Mixlists', columns: ['title']);
    return rows.any(
      (row) => (row['title'] as String).trim().toLowerCase() == normalized,
    );
  }

  /// Gets or creates an Artist by [spotifyURI]; if null, falls back to a
  /// case-insensitive name match against ALL artists, not just URI-less
  /// ones (scoping to URI-less rows previously caused mass duplication).
  Future<int> getOrCreateArtistId(
    DatabaseExecutor txn, {
    required String? spotifyURI,
    required String name,
    String? genres,
  }) async {
    List<Map<String, Object?>> existing;
    if (spotifyURI != null) {
      existing = await txn.query(
        'Artists',
        columns: ['id'],
        where: 'spotifyURI = ?',
        whereArgs: [spotifyURI],
        limit: 1,
      );
    } else {
      final normalized = name.trim().toLowerCase();
      final all = await txn.query('Artists', columns: ['id', 'name']);
      existing = all
          .where(
            (row) => (row['name'] as String).trim().toLowerCase() == normalized,
          )
          .take(2)
          .toList();
    }

    if (existing.length == 1) {
      final artistId = existing.first['id'] as int;
      if (genres != null) {
        await txn.update(
          'Artists',
          {'genres': genres},
          where: 'id = ? AND genres IS NULL',
          whereArgs: [artistId],
        );
      }
      return artistId;
    }

    return txn.insert('Artists', {
      'spotifyURI': spotifyURI,
      'name': name,
      'genres': genres,
    });
  }

  /// Matches by [spotifyURI] first, then falls back to a case-insensitive
  /// `(name, artistId)` match -- Spotify doesn't always serve the same
  /// album URI for what's really the same album across different lookups
  /// (reissues, regional catalog variants, messy metadata on smaller
  /// labels), so a URI-first-only match let a real bulk import split one
  /// album's tracks across several duplicate `Albums` rows. On a
  /// fallback match, the row's spotifyURI is refreshed to the new value
  /// -- same "reassignment" handling [getOrCreateSongId] already has for
  /// tracks. Backfills [recordLabel] only if the row doesn't already have
  /// one. Zero or 2+ name matches falls through to inserting a new row,
  /// same ambiguous-means-don't-guess posture as [getOrCreateArtistId].
  Future<int> getOrCreateAlbumId(
    DatabaseExecutor txn, {
    required String? spotifyURI,
    required String name,
    required String? releaseDate,
    required String? coverImageURL,
    required int artistId,
    String? recordLabel,
  }) async {
    if (spotifyURI != null) {
      final byUri = await txn.query(
        'Albums',
        columns: ['id'],
        where: 'spotifyURI = ?',
        whereArgs: [spotifyURI],
        limit: 1,
      );
      if (byUri.isNotEmpty) {
        final albumId = byUri.first['id'] as int;
        if (recordLabel != null) {
          await txn.update(
            'Albums',
            {'recordLabel': recordLabel},
            where: 'id = ? AND recordLabel IS NULL',
            whereArgs: [albumId],
          );
        }
        return albumId;
      }
    }

    final normalized = name.trim().toLowerCase();
    final forArtist = await txn.query(
      'Albums',
      columns: ['id', 'name'],
      where: 'artist = ?',
      whereArgs: [artistId],
    );
    final matches = forArtist
        .where(
          (row) => (row['name'] as String).trim().toLowerCase() == normalized,
        )
        .take(2)
        .toList();

    if (matches.length == 1) {
      final albumId = matches.first['id'] as int;
      if (spotifyURI != null) {
        await txn.update(
          'Albums',
          {'spotifyURI': spotifyURI},
          where: 'id = ? AND spotifyURI != ?',
          whereArgs: [albumId, spotifyURI],
        );
      }
      if (recordLabel != null) {
        await txn.update(
          'Albums',
          {'recordLabel': recordLabel},
          where: 'id = ? AND recordLabel IS NULL',
          whereArgs: [albumId],
        );
      }
      return albumId;
    }

    return txn.insert('Albums', {
      'spotifyURI': spotifyURI,
      'name': name,
      'releaseDate': releaseDate,
      'coverImageURL': coverImageURL,
      'recordLabel': recordLabel,
      'artist': artistId,
    });
  }

  /// Matches by [spotifyURI] first, then falls back to `(name, albumId,
  /// durationMs)` since Spotify reassigns track URIs over time. On a
  /// fallback match, the row's spotifyURI is refreshed to the new value.
  Future<int> getOrCreateSongId(
    DatabaseExecutor txn, {
    required String spotifyURI,
    required String name,
    required String artists,
    required String? artistsURIs,
    required int albumId,
    required int durationMs,
    required SongExtraData Function(int songId) buildExtraData,
  }) async {
    final byUri = await txn.query(
      'Songs',
      columns: ['id'],
      where: 'spotifyURI = ?',
      whereArgs: [spotifyURI],
      limit: 1,
    );
    if (byUri.isNotEmpty) return byUri.first['id'] as int;

    // Re-masters can shift reported duration by ~100ms; 1000ms tolerance
    // covers that without matching a genuinely different version.
    const toleranceMs = 1000;
    Future<List<int>> matchesAmong(List<Map<String, Object?>> candidates) async {
      final normalizedName = name.trim().toLowerCase();
      final matches = <int>[];
      for (final row in candidates) {
        if ((row['name'] as String).trim().toLowerCase() != normalizedName) {
          continue;
        }
        final candidateId = row['id'] as int;
        final extraRows = await txn.query(
          'SongsExtraData',
          columns: ['durationMs'],
          where: 'song = ?',
          whereArgs: [candidateId],
          limit: 1,
        );
        if (extraRows.isEmpty) continue;
        final candidateDuration = extraRows.first['durationMs'] as int;
        if ((candidateDuration - durationMs).abs() <= toleranceMs) {
          matches.add(candidateId);
        }
      }
      return matches;
    }

    final sameAlbum = await txn.query(
      'Songs',
      columns: ['id', 'name'],
      where: 'album = ?',
      whereArgs: [albumId],
    );
    var matchingIds = await matchesAmong(sameAlbum);

    // Fall back to a library-wide match when nothing matched within the
    // album -- doesn't reassign album/artist, just stops duplicate tracks.
    if (matchingIds.isEmpty) {
      final allSongs = await txn.query('Songs', columns: ['id', 'name']);
      matchingIds = await matchesAmong(allSongs);
    }

    if (matchingIds.length == 1) {
      final songId = matchingIds.first;
      await txn.update(
        'Songs',
        {'spotifyURI': spotifyURI},
        where: 'id = ? AND spotifyURI != ?',
        whereArgs: [songId, spotifyURI],
      );
      return songId;
    }

    final songId = await txn.insert('Songs', {
      'spotifyURI': spotifyURI,
      'name': name,
      'artists': artists,
      'artistsURIs': artistsURIs,
      'album': albumId,
    });
    final extra = buildExtraData(songId);
    final extraMap = extra.toMap()..remove('id');
    await txn.insert('SongsExtraData', extraMap);
    return songId;
  }

  /// Inserts a SongsAudioFeatures row for [songId] from [row] if one
  /// doesn't already exist. Never overwrites -- audio features don't
  /// change once captured.
  Future<void> upsertSongAudioFeatures(
    DatabaseExecutor txn, {
    required int songId,
    required MixlistCsvRow row,
  }) async {
    final existing = await txn.query(
      'SongsAudioFeatures',
      columns: ['id'],
      where: 'song = ?',
      whereArgs: [songId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    if (row.danceability == null &&
        row.energy == null &&
        row.key == null &&
        row.loudness == null &&
        row.mode == null &&
        row.speechiness == null &&
        row.acousticness == null &&
        row.instrumentalness == null &&
        row.liveness == null &&
        row.valence == null &&
        row.tempo == null &&
        row.timeSignature == null) {
      return;
    }

    await txn.insert('SongsAudioFeatures', {
      'song': songId,
      'danceability': row.danceability,
      'energy': row.energy,
      'key': row.key,
      'loudness': row.loudness,
      'mode': row.mode,
      'speechiness': row.speechiness,
      'acousticness': row.acousticness,
      'instrumentalness': row.instrumentalness,
      'liveness': row.liveness,
      'valence': row.valence,
      'tempo': row.tempo,
      'timeSignature': row.timeSignature,
    });
  }

  /// Full atomic import of a mixlist's rows. Throws
  /// [MixlistTitleExistsException] if [title] collides; any other failure
  /// rolls back the whole transaction.
  Future<int> importMixlistFromCsvRows({
    required String title,
    required String description,
    required List<MixlistCsvRow> rows,
  }) async {
    if (rows.isEmpty) {
      throw ArgumentError('Cannot import a mixlist with zero rows');
    }
    if (await mixlistTitleExists(title)) {
      throw MixlistTitleExistsException(title);
    }

    final dateCreated = rows
        .map((r) => r.addedAt)
        .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);

    return _db.transaction<int>((txn) async {
      final mixlistId = await txn.insert('Mixlists', {
        'title': title,
        'description': description,
        'dateCreated': dateCreated,
      });

      var position = 1;
      for (final row in rows) {
        final artistId = await getOrCreateArtistId(
          txn,
          spotifyURI: row.albumArtistURI,
          name: row.albumArtistName,
          genres: row.genres,
        );
        final albumId = await getOrCreateAlbumId(
          txn,
          spotifyURI: row.albumURI,
          name: row.albumName,
          releaseDate: row.albumReleaseDate,
          coverImageURL: row.albumImageURL,
          artistId: artistId,
          recordLabel: row.recordLabel,
        );
        final songId = await getOrCreateSongId(
          txn,
          spotifyURI: row.trackURI,
          name: row.trackName,
          artists: row.artistNames,
          artistsURIs: row.artistURIs,
          albumId: albumId,
          durationMs: row.durationMs,
          buildExtraData: (songId) => SongExtraData(
            id: 0,
            discNumber: row.discNumber,
            albumTrackNumber: row.albumTrackNumber,
            durationMs: row.durationMs,
            audioPreviewURL: row.audioPreviewURL,
            isExplicit: row.isExplicit,
            popularity: row.popularity,
            isrc: row.isrc,
            songID: songId,
          ),
        );
        await upsertSongAudioFeatures(txn, songId: songId, row: row);
        await txn.insert('SongsMixlists', {
          'positionIndex': position,
          'dateAdded': row.addedAt,
          'song': songId,
          'mixlist': mixlistId,
        });
        position++;
      }
      return mixlistId;
    });
  }
}
