import 'dart:io';

import 'package:mixlists_importer/src/auth/credential_store.dart';
import 'package:mixlists_importer/src/auth/spotify_auth.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mixlists_importer_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('read returns null when no credentials file exists yet', () async {
    final store = CredentialStore(
      overridePath: '${tempDir.path}/nested/credentials.json',
    );
    expect(await store.read(), isNull);
  });

  test('write then read round-trips all fields', () async {
    final path = '${tempDir.path}/nested/credentials.json';
    final store = CredentialStore(overridePath: path);
    final tokens = SpotifyTokens(
      accessToken: 'access-123',
      refreshToken: 'refresh-456',
      expiresAt: DateTime.utc(2026, 1, 1, 12),
      scope: 'playlist-read-private playlist-read-collaborative',
    );

    await store.write(tokens);
    final reloaded = await store.read();

    expect(reloaded, isNotNull);
    expect(reloaded!.accessToken, tokens.accessToken);
    expect(reloaded.refreshToken, tokens.refreshToken);
    expect(reloaded.expiresAt, tokens.expiresAt);
    expect(reloaded.scope, tokens.scope);
  });

  test('write creates parent directories that do not exist yet', () async {
    final path = '${tempDir.path}/a/b/c/credentials.json';
    final store = CredentialStore(overridePath: path);
    await store.write(
      SpotifyTokens(
        accessToken: 'x',
        refreshToken: 'y',
        expiresAt: DateTime.now(),
        scope: 's',
      ),
    );
    expect(File(path).existsSync(), isTrue);
  });

  test('isExpired is true 30s before expiresAt and false well before it', () {
    final almostExpired = SpotifyTokens(
      accessToken: 'a',
      refreshToken: 'r',
      expiresAt: DateTime.now().add(const Duration(seconds: 10)),
      scope: 's',
    );
    final freshlyIssued = SpotifyTokens(
      accessToken: 'a',
      refreshToken: 'r',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      scope: 's',
    );
    expect(almostExpired.isExpired, isTrue);
    expect(freshlyIssued.isExpired, isFalse);
  });
}
