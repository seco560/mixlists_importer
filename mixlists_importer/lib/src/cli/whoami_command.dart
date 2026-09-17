import 'dart:io';

import 'package:args/command_runner.dart';

import '../auth/auth_session.dart';
import '../auth/credential_store.dart';
import '../auth/spotify_auth.dart';
import 'client_id.dart';

/// Exercises the stored-login + silent-refresh path without doing any
/// real work -- confirms `auth` doesn't need to be re-run every time.
class WhoAmICommand extends Command<void> {
  WhoAmICommand() {
    argParser.addOption('client-id', help: 'Spotify app Client ID (or set SPOTIFY_CLIENT_ID)');
  }

  @override
  String get name => 'whoami';

  @override
  String get description =>
      'Prints the currently logged-in Spotify account, refreshing the '
      'stored token first if it expired. Fails if `auth` has not been run.';

  @override
  Future<void> run() async {
    final clientId = resolveClientId(argResults!['client-id'] as String?);
    if (clientId == null) {
      stderr.writeln(clientIdMissingMessage);
      exitCode = 1;
      return;
    }

    final auth = SpotifyAuth(clientId: clientId);
    final session = AuthSession(auth, CredentialStore());

    try {
      final tokens = await session.ensureValidTokens();
      final displayName = await auth.fetchCurrentUserDisplayName(
        tokens.accessToken,
      );
      print(displayName);
    } on SpotifyAuthException catch (e) {
      stderr.writeln(e);
      exitCode = 1;
    }
  }
}
