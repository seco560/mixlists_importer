import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mixlists_core/mixlists_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../auth/auth_session.dart';
import '../auth/credential_store.dart';
import '../import/ordering.dart';
import '../import/row_mapper.dart';
import '../spotify_api/artist_genre_cache.dart';
import '../spotify_api/me.dart';
import '../spotify_api/paging.dart';
import '../spotify_api/playlists.dart';
import '../spotify_api/spotify_client.dart';
import 'client_id.dart';
import 'order_review.dart';

class RunCommand extends Command<void> {
  RunCommand() {
    argParser
      ..addOption('client-id', help: 'Spotify app Client ID (or set SPOTIFY_CLIENT_ID)')
      ..addOption('out', mandatory: true, help: 'Output path for the new mixlists.db')
      ..addFlag(
        'yes',
        abbr: 'y',
        negatable: false,
        help: 'Accept the proposed import order without an interactive review',
      );
  }

  @override
  String get name => 'run';

  @override
  String get description =>
      'One-shot bulk import: pulls every owned or collaborative playlist '
      'into a fresh mixlists.db.';

  @override
  Future<void> run() async {
    final outPath = argResults!['out'] as String;
    if (await File(outPath).exists()) {
      stderr.writeln(
        '$outPath already exists -- refusing to overwrite. Remove it or '
        'pick a different --out path.',
      );
      exitCode = 1;
      return;
    }

    final clientIdOverride = resolveClientId(argResults!['client-id'] as String?);
    final session = AuthSession(CredentialStore(), clientIdOverride: clientIdOverride);
    final client = SpotifyClient(session);

    print('Fetching account info...');
    final me = await fetchCurrentUser(client);
    print('Logged in as: ${me.displayName} (${me.id})');

    print('Listing playlists...');
    final playlistResult = await fetchImportablePlaylists(
      client,
      currentUserId: me.id,
    );
    if (playlistResult.skippedFollowedOnly > 0) {
      print(
        '${playlistResult.skippedFollowedOnly} playlist(s) skipped '
        '(followed but not owned/collaborative -- not importable).',
      );
    }
    print('${playlistResult.importable.length} playlist(s) to fetch.');

    final genreCache = ArtistGenreCache(client);
    final batches = <PlaylistImportBatch>[];

    for (final playlist in playlistResult.importable) {
      stdout.write('Fetching "${playlist.name}"... ');
      final rawItems = await fetchAllPages(
        client,
        Uri.parse(
          'https://api.spotify.com/v1/playlists/${playlist.id}/items?limit=50',
        ),
      );

      final rows = <MixlistCsvRow>[];
      for (final wrapper in rawItems) {
        if (shouldSkipPlaylistItem(wrapper)) continue;
        final item = wrapper['item'] as Map<String, Object?>;
        final album = item['album'] as Map<String, Object?>;
        final albumArtistId =
            (album['artists'] as List).cast<Map<String, Object?>>().first['id']
                as String;
        final genres = await genreCache.genresFor(albumArtistId);
        rows.add(rowFromPlaylistItem(wrapper, albumArtistGenres: genres));
      }

      print('${rows.length} track(s).');
      if (rows.isEmpty) {
        print('  (skipping -- nothing importable in this playlist)');
        continue;
      }
      batches.add(PlaylistImportBatch(playlist: playlist, rows: rows));
    }

    if (batches.isEmpty) {
      print('\nNothing to import.');
      return;
    }

    final ordered = await reviewImportOrder(
      batches,
      acceptDefault: argResults!['yes'] as bool,
    );

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await databaseFactory.openDatabase(
      outPath,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: (db, version) async {
          await createSchemaV2(db);
          await applySchemaV3(db);
          await applySchemaV4(db);
          await applySchemaV5(db);
        },
      ),
    );
    final ingestion = MixlistIngestion(db);

    var imported = 0;
    for (final batch in ordered) {
      try {
        await ingestion.importMixlistFromCsvRows(
          title: batch.playlist.name,
          description: batch.playlist.description,
          rows: batch.rows,
        );
        imported++;
        print('Imported "${batch.playlist.name}" (${batch.rows.length} tracks).');
      } on MixlistTitleExistsException catch (e) {
        print('Skipped "${batch.playlist.name}": $e');
      }
    }
    await db.close();

    print('\nDone. $imported/${ordered.length} playlist(s) written to $outPath.');
  }
}
