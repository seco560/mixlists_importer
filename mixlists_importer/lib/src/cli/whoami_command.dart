import 'dart:io';

import 'package:args/command_runner.dart';

import '../auth/auth_session.dart';
import '../auth/credential_store.dart';
import '../auth/spotify_auth.dart';

/// Exercises the stored-login + silent-refresh path without doing any
/// real work -- confirms `auth` doesn't need to be re-run every time.
class WhoAmICommand extends Command<void> {
  WhoAmICommand() {
    argParser.addOption(
      'client-id',
      help:
          'Override the Client ID to refresh under (or set SPOTIFY_CLIENT_ID). '
          'Not needed for a still-valid login -- the stored Client ID is used '
          'automatically when a refresh is actually needed.',
    );
  }

  @override
  String get name => 'whoami';

  @override
  String get description =>
      'Prints the currently logged-in Spotify account, refreshing the '
      'stored token first if it expired. Fails if `auth` has not been run.';

  @override
  Future<void> run() async {
    final clientIdOverride =
        (argResults!['client-id'] as String?) ??
        Platform.environment['SPOTIFY_CLIENT_ID'];
    final session = AuthSession(
      CredentialStore(),
      clientIdOverride: clientIdOverride,
    );

    try {
      final tokens = await session.ensureValidTokens();
      final displayName = await fetchCurrentUserDisplayName(tokens.accessToken);
      print(displayName);
    } on SpotifyAuthException catch (e) {
      stderr.writeln(e);
      exitCode = 1;
    }
  }
}
