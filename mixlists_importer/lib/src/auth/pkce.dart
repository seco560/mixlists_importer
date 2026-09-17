import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// A PKCE (Proof Key for Code Exchange) verifier/challenge pair, per
/// RFC 7636. Required for the Authorization Code flow since this is a
/// public client (a personal CLI tool) that can't safely hold a client
/// secret.
class PkcePair {
  const PkcePair(this.verifier, this.challenge);

  final String verifier;
  final String challenge;

  static PkcePair generate() {
    // 64 raw bytes -> ~86 base64url chars, comfortably within the
    // 43-128 char range Spotify requires for the verifier.
    final verifier = randomUrlSafeToken(64);
    final challenge = base64UrlEncode(
      sha256.convert(utf8.encode(verifier)).bytes,
    ).replaceAll('=', '');
    return PkcePair(verifier, challenge);
  }
}

/// A cryptographically random, URL-safe token -- used both for the PKCE
/// verifier and as the OAuth `state` CSRF value.
String randomUrlSafeToken(int byteLength) {
  final random = Random.secure();
  final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
