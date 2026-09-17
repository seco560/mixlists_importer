import 'package:mixlists_importer/src/spotify_api/html_entities.dart';
import 'package:test/test.dart';

void main() {
  test('decodes hex numeric entities (real example from a live description)', () {
    expect(unescapeHtmlEntities('&#x2F;&#x2F; wealth of time'), '// wealth of time');
  });

  test('decodes decimal numeric entities', () {
    expect(unescapeHtmlEntities('a&#38;b'), 'a&b');
  });

  test('decodes common named entities', () {
    expect(unescapeHtmlEntities('Rock &amp; Roll'), 'Rock & Roll');
    expect(unescapeHtmlEntities('&lt;tag&gt;'), '<tag>');
    expect(unescapeHtmlEntities('&quot;quoted&quot;'), '"quoted"');
  });

  test('leaves plain text untouched', () {
    expect(unescapeHtmlEntities('is it still Summer...'), 'is it still Summer...');
  });

  test('handles an empty string', () {
    expect(unescapeHtmlEntities(''), '');
  });
}
