import 'dart:io';

import 'package:args/command_runner.dart';

import '../auth/credential_store.dart';
import '../auth/spotify_auth.dart';
import 'browser.dart';
import 'client_id.dart';

class AuthCommand extends Command<void> {
  AuthCommand() {
    argParser
      ..addOption('client-id', help: 'Spotify app Client ID (or set SPOTIFY_CLIENT_ID)')
      ..addOption(
        'port',
        defaultsTo: '43847',
        help:
            'Local loopback port for the OAuth redirect. Must exactly match '
            'a Redirect URI registered on your Spotify app '
            '(http://127.0.0.1:<port>/callback).',
      );
  }

  @override
  String get name => 'auth';

  @override
  String get description =>
      'Log in to Spotify (opens a browser) and store a refresh token for '
      'other commands to use. Re-running this replaces the stored login.';

  @override
  Future<void> run() async {
    final clientId = resolveClientId(argResults!['client-id'] as String?);
    if (clientId == null) {
      stderr.writeln(clientIdMissingMessage);
      exitCode = 1;
      return;
    }
    final port = int.parse(argResults!['port'] as String);

    final auth = SpotifyAuth(clientId: clientId, port: port);
    print('Redirect URI for this login: ${auth.redirectUri}');
    print(
      "Make sure that exact URI is registered under your app's Redirect "
      "URIs in the Spotify Developer Dashboard, or this will fail with "
      "INVALID_CLIENT.",
    );

    final tokens = await auth.login(
      onReadyToAuthorize: (url) => openInBrowser(url),
    );

    await CredentialStore().write(tokens);

    final displayName = await fetchCurrentUserDisplayName(tokens.accessToken);
    print('Authenticated as: $displayName');
    print('Credentials saved to ${CredentialStore.defaultCredentialsPath()}');
  }
}
