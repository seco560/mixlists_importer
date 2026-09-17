import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:mixlists_importer/src/auth/pkce.dart';
import 'package:test/test.dart';

void main() {
  group('PkcePair.generate', () {
    test('verifier length is within the 43-128 char range Spotify requires', () {
      final pair = PkcePair.generate();
      expect(pair.verifier.length, greaterThanOrEqualTo(43));
      expect(pair.verifier.length, lessThanOrEqualTo(128));
    });

    test('verifier and challenge contain no base64 padding or unsafe chars', () {
      final pair = PkcePair.generate();
      expect(pair.verifier, isNot(contains('=')));
      expect(pair.verifier, isNot(contains('+')));
      expect(pair.verifier, isNot(contains('/')));
      expect(pair.challenge, isNot(contains('=')));
    });

    test('challenge is the S256 transform of the verifier (RFC 7636)', () {
      final pair = PkcePair.generate();
      final expectedChallenge = base64UrlEncode(
        sha256.convert(utf8.encode(pair.verifier)).bytes,
      ).replaceAll('=', '');
      expect(pair.challenge, equals(expectedChallenge));
    });

    test('two calls produce different verifiers', () {
      final a = PkcePair.generate();
      final b = PkcePair.generate();
      expect(a.verifier, isNot(equals(b.verifier)));
    });
  });

  group('randomUrlSafeToken', () {
    test('produces different tokens across calls', () {
      final a = randomUrlSafeToken(16);
      final b = randomUrlSafeToken(16);
      expect(a, isNot(equals(b)));
    });
  });
}
