import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mixlists_importer/src/cli/auth_command.dart';
import 'package:mixlists_importer/src/cli/run_command.dart';
import 'package:mixlists_importer/src/cli/supplement_command.dart';
import 'package:mixlists_importer/src/cli/whoami_command.dart';

Future<void> main(List<String> arguments) async {
  final runner = CommandRunner<void>(
    'mixlists_importer',
    'Pulls your Spotify playlists into a local mixlists.db.',
  )
    ..addCommand(AuthCommand())
    ..addCommand(WhoAmICommand())
    ..addCommand(RunCommand())
    ..addCommand(SupplementCommand());

  try {
    await runner.run(arguments);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = 64;
  }
}
