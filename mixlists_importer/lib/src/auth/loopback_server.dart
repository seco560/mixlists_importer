import 'dart:async';
import 'dart:io';

/// What Spotify sent back to the loopback redirect.
class AuthorizationResult {
  const AuthorizationResult({this.code, this.error, required this.state});

  final String? code;
  final String? error;
  final String state;
}

/// A short-lived local HTTP server that receives the OAuth redirect for
/// the Authorization Code + PKCE flow. Spotify no longer accepts
/// `http://localhost:...` as a redirect URI -- only loopback IP literals
/// (`127.0.0.1`) -- so this binds explicitly to the loopback address, not
/// `anyIPv4`/`localhost`.
class LoopbackServer {
  LoopbackServer({required this.port});

  final int port;
  HttpServer? _server;

  Uri get redirectUri => Uri.parse('http://127.0.0.1:$port/callback');

  /// Starts listening and completes once Spotify redirects back here with
  /// either `code`/`state` or an `error`. Closes itself after the first
  /// request to `/callback`.
  Future<AuthorizationResult> waitForCallback() async {
    final completer = Completer<AuthorizationResult>();
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

    _server!.listen((request) async {
      if (request.uri.path != '/callback') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final params = request.uri.queryParameters;
      final result = AuthorizationResult(
        code: params['code'],
        error: params['error'],
        state: params['state'] ?? '',
      );

      request.response
        ..headers.contentType = ContentType.html
        ..write(_page(success: result.error == null && result.code != null));
      await request.response.close();

      if (!completer.isCompleted) completer.complete(result);
    });

    return completer.future;
  }

  Future<void> close() async {
    await _server?.close(force: true);
  }

  String _page({required bool success}) {
    final message = success
        ? 'Mixlists Importer is authenticated. You can close this tab.'
        : 'Something went wrong. Check the terminal, then close this tab.';
    return '<html><body style="font-family: sans-serif; text-align: center; '
        'margin-top: 4em;"><h2>$message</h2></body></html>';
  }
}
