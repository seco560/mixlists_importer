import 'spotify_client.dart';

class SpotifyUser {
  const SpotifyUser({required this.id, required this.displayName});
  final String id;
  final String displayName;
}

Future<SpotifyUser> fetchCurrentUser(SpotifyClient client) async {
  final json = await client.getJson(Uri.parse('https://api.spotify.com/v1/me'));
  return SpotifyUser(
    id: json['id'] as String,
    displayName: (json['display_name'] as String?) ?? (json['id'] as String),
  );
}
