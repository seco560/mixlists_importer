import 'spotify_client.dart';

/// Follows the `next` field Spotify includes on every cursor-paginated
/// response (`/me/playlists`, `/playlists/{id}/items`, ...) until it's
/// null, collecting every page's `items`. Using `next` directly avoids
/// hand-rolling `limit`/`offset` math -- Spotify already hands back the
/// exact URL to fetch next, including any query params it wants applied.
Future<List<Map<String, Object?>>> fetchAllPages(
  SpotifyClient client,
  Uri firstPage,
) async {
  final items = <Map<String, Object?>>[];
  Uri? next = firstPage;
  while (next != null) {
    final page = await client.getJson(next);
    items.addAll((page['items'] as List).cast<Map<String, Object?>>());
    final nextUrl = page['next'] as String?;
    next = nextUrl == null ? null : Uri.parse(nextUrl);
  }
  return items;
}
