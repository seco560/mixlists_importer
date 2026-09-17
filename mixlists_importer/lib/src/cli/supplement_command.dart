import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mixlists_core/mixlists_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SupplementCommand extends Command<void> {
  SupplementCommand() {
    argParser
      ..addOption('db', mandatory: true, help: 'Path to an existing mixlists.db to update in place')
      ..addOption('csv-dir', mandatory: true, help: 'Directory of CSV files to read genres/label/popularity/audio-features from');
  }

  @override
  String get name => 'supplement';

  @override
  String get description =>
      'Backfills genres, record label, popularity, and audio features '
      'from CSV exports (e.g. Exportify) onto songs already in --db -- '
      'fields the Spotify API no longer provides to personal apps. Never '
      'creates new songs or touches mixlist membership.';

  @override
  Future<void> run() async {
    final dbPath = argResults!['db'] as String;
    final csvDir = argResults!['csv-dir'] as String;

    final dbFile = File(dbPath);
    if (!dbFile.existsSync()) {
      stderr.writeln('Database not found at $dbPath');
      exitCode = 1;
      return;
    }
    if (!Directory(csvDir).existsSync()) {
      stderr.writeln('CSV directory not found at $csvDir');
      exitCode = 1;
      return;
    }

    // Back up first, non-negotiable -- same posture as the Flutter app's
    // bin/backfill_new_format_data.dart, which this generalizes.
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupPath = '$dbPath.pre-supplement-backup-$timestamp';
    dbFile.copySync(backupPath);
    print('Backed up $dbPath -> $backupPath');

    // Work on a separate copy, never the original, until the whole run
    // succeeds. sqflite_common_ffi resolves a relative path against its
    // own default databases directory, not the working directory, so an
    // absolute path is required here or it silently opens a different,
    // empty file.
    final workingPath = p.absolute('$dbPath.supplementing');
    final workingFile = File(workingPath);
    if (workingFile.existsSync()) workingFile.deleteSync();
    dbFile.copySync(workingPath);

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await databaseFactory.openDatabase(workingPath);

    final supplement = MixlistSupplement(db);
    final overall = SupplementSummary();
    final warnings = <String>[];

    final csvFiles =
        Directory(csvDir).listSync().whereType<File>().where(
          (f) => f.path.toLowerCase().endsWith('.csv'),
        ).toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    if (csvFiles.isEmpty) {
      stderr.writeln('No .csv files found under $csvDir');
      await db.close();
      workingFile.deleteSync();
      exitCode = 1;
      return;
    }
    print('Found ${csvFiles.length} CSV file(s) under $csvDir.');

    for (final file in csvFiles) {
      final List<MixlistCsvRow> rows;
      try {
        rows = MixlistCsvParser.parse(file.readAsStringSync());
      } on MixlistCsvParseException catch (e) {
        warnings.add('Skipped ${file.path}: $e');
        continue;
      }
      final summary = await supplement.applyCsvRows(rows);
      overall.mergeWith(summary);
      print(
        '${p.basename(file.path)}: ${summary.matched} matched, '
        '${summary.unmatched} unmatched (of ${rows.length} rows)',
      );
    }

    await db.close();

    // Only replace the original once the whole run succeeded.
    workingFile.copySync(dbPath);
    workingFile.deleteSync();

    print('\n--- Summary ---');
    print('Songs matched and backfilled: ${overall.matched}');
    print('Rows with no matching song:   ${overall.unmatched}');
    if (warnings.isNotEmpty) {
      print('\nWarnings:');
      for (final w in warnings) {
        print('  - $w');
      }
    }
    print('\nDone. $dbPath updated. Backup kept at $backupPath.');
  }
}
