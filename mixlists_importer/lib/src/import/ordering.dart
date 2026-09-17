import 'package:mixlists_core/mixlists_core.dart';

import '../spotify_api/playlists.dart';

/// One playlist's fetched, mapped rows, not yet written to a db.
class PlaylistImportBatch {
  PlaylistImportBatch({required this.playlist, required this.rows});

  final SpotifyPlaylistSummary playlist;
  final List<MixlistCsvRow> rows;

  /// Same `min(added_at)` heuristic `Mixlists.dateCreated` already uses
  /// -- Spotify exposes no real playlist creation date, so this is the
  /// best-effort proxy used both for the stored value and, here, for
  /// deciding import order (which becomes `Mixlists.id` order, the
  /// app's authoritative chronology).
  String get earliestAddedAt =>
      rows.map((r) => r.addedAt).reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
}

/// Sorts ascending by [PlaylistImportBatch.earliestAddedAt] -- the
/// proposed import order. Known-imperfect (a playlist duplicated from an
/// older one inherits its tracks' old `added_at` values and looks
/// artificially old) -- worth a manual sanity check once per bulk run,
/// not worth chasing a perfect signal that doesn't exist.
List<PlaylistImportBatch> sortByEarliestAddedAt(
  List<PlaylistImportBatch> batches,
) {
  final sorted = [...batches]
    ..sort((a, b) => a.earliestAddedAt.compareTo(b.earliestAddedAt));
  return sorted;
}
