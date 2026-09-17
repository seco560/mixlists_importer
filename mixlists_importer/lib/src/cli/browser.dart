import 'dart:io';

/// Best-effort attempt to open [url] in the user's default browser.
/// Always also prints the URL, since auto-open can silently fail (no
/// display, unusual desktop setup, remote/headless session over SSH).
Future<void> openInBrowser(Uri url) async {
  try {
    if (Platform.isLinux) {
      await Process.run('xdg-open', [url.toString()]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url.toString()]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url.toString()]);
    }
  } catch (_) {
    // Best-effort only -- the printed URL below is the real fallback.
  }
  print('Opening in your browser (if that didn\'t work, open this URL manually):');
  print(url);
}
