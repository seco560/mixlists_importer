import 'dart:io';

import '../import/ordering.dart';

/// Prints the proposed import order and, unless [acceptDefault], offers
/// to edit it in `$EDITOR` before returning the final order to write in.
/// Mirrors the existing CSV-import screen's review-before-confirm
/// pattern, adapted to a CLI (no custom TUI needed -- same idea as
/// `git rebase -i`).
Future<List<PlaylistImportBatch>> reviewImportOrder(
  List<PlaylistImportBatch> batches, {
  required bool acceptDefault,
}) async {
  final proposed = sortByEarliestAddedAt(batches);

  print('\nProposed import order (earliest-added-track first):');
  for (var i = 0; i < proposed.length; i++) {
    final batch = proposed[i];
    final date = batch.earliestAddedAt.split('T').first;
    print(
      '  ${i + 1}. ${batch.playlist.name}  ($date, ${batch.rows.length} tracks)',
    );
  }

  if (acceptDefault) return proposed;

  stdout.write('\nAccept this order? [Y/n/e=edit in \$EDITOR]: ');
  final response = stdin.readLineSync()?.trim().toLowerCase() ?? '';
  if (response != 'e') return proposed;

  final editor = Platform.environment['EDITOR'];
  if (editor == null || editor.isEmpty) {
    stderr.writeln('\$EDITOR is not set -- keeping the proposed order.');
    return proposed;
  }

  return _editOrder(proposed, editor);
}

Future<List<PlaylistImportBatch>> _editOrder(
  List<PlaylistImportBatch> proposed,
  String editor,
) async {
  final scratchFile = File(
    '${Directory.systemTemp.path}/mixlists_importer_order_'
    '${DateTime.now().millisecondsSinceEpoch}.txt',
  );
  await scratchFile.writeAsString(
    '# Reorder these lines to change import order, then save and close.\n'
    '# Do not remove, duplicate, or hand-edit the leading number -- it\n'
    '# identifies each entry; only line ORDER matters.\n'
    '${[for (var i = 0; i < proposed.length; i++) '${i + 1}\t${proposed[i].playlist.name}'].join('\n')}\n',
  );

  final process = await Process.start(
    editor,
    [scratchFile.path],
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    stderr.writeln('Editor exited with an error -- keeping the proposed order.');
    await scratchFile.delete();
    return proposed;
  }

  final lines = (await scratchFile.readAsLines())
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toList();
  await scratchFile.delete();

  final indices = <int>[];
  for (final line in lines) {
    final tabIndex = line.indexOf('\t');
    final numberPart = tabIndex == -1 ? line : line.substring(0, tabIndex);
    final n = int.tryParse(numberPart.trim());
    if (n == null) {
      stderr.writeln('Could not parse "$line" -- keeping the proposed order.');
      return proposed;
    }
    indices.add(n);
  }

  final expected = List.generate(proposed.length, (i) => i + 1)..sort();
  final actual = [...indices]..sort();
  if (expected.length != actual.length ||
      !Iterable.generate(
        expected.length,
      ).every((i) => expected[i] == actual[i])) {
    stderr.writeln(
      'Edited file is not a valid reordering of the original entries -- '
      'keeping the proposed order.',
    );
    return proposed;
  }

  return [for (final n in indices) proposed[n - 1]];
}
