/// Spotify HTML-escapes some characters in playlist descriptions (e.g.
/// `//` comes back as `&#x2F;&#x2F;`, confirmed against a real response).
/// No `package:html` dependency needed for this -- just numeric character
/// references plus the handful of named entities that actually show up.
final _numericEntity = RegExp(r'&#(x?)([0-9a-fA-F]+);');

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
};

String unescapeHtmlEntities(String input) {
  var result = input.replaceAllMapped(_numericEntity, (match) {
    final isHex = match.group(1) == 'x';
    final code = int.parse(match.group(2)!, radix: isHex ? 16 : 10);
    return String.fromCharCode(code);
  });
  for (final entry in _namedEntities.entries) {
    result = result.replaceAll('&${entry.key};', entry.value);
  }
  return result;
}
