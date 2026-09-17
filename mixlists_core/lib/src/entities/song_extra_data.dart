class SongExtraData {
  final int id;
  final int? discNumber;
  final int? albumTrackNumber;
  final int durationMs;
  final String? audioPreviewURL;
  final bool isExplicit;
  final int? popularity; // no longer obtainable via the Spotify API
  final String? isrc;
  final int songID;

  SongExtraData({
    required this.id,
    required this.discNumber,
    required this.albumTrackNumber,
    required this.durationMs,
    required this.audioPreviewURL,
    required this.isExplicit,
    required this.popularity,
    required this.isrc,
    required this.songID,
  });

  factory SongExtraData.fromMap(Map<String, Object?> map) {
    return SongExtraData(
      id: map['id'] as int,
      discNumber: map['discNumber'] as int?,
      albumTrackNumber: map['albumTrackNumber'] as int?,
      durationMs: map['durationMs'] as int,
      audioPreviewURL: map['audioPreviewURL'] as String?,
      isExplicit: (map['explicit'] as String).toLowerCase() == 'true', // stored as text rather than SQLite 1/0 bool
      popularity: map['popularity'] as int?,
      isrc: map['ISRC'] as String?,
      songID: map['song'] as int,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'discNumber': discNumber,
      'albumTrackNumber': albumTrackNumber,
      'durationMs': durationMs,
      'audioPreviewURL': audioPreviewURL,
      'explicit': isExplicit ? 'true' : 'false',
      'popularity': popularity,
      'ISRC': isrc,
      'song': songID,
    };
  }

}
