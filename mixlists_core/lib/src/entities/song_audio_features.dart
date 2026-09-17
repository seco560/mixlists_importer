class SongAudioFeatures {
  final int id;
  final double? danceability;
  final double? energy;
  final int? key;
  final double? loudness;
  final int? mode;
  final double? speechiness;
  final double? acousticness;
  final double? instrumentalness;
  final double? liveness;
  final double? valence;
  final double? tempo;
  final int? timeSignature;
  final int songID;

  SongAudioFeatures({
    required this.id,
    required this.danceability,
    required this.energy,
    required this.key,
    required this.loudness,
    required this.mode,
    required this.speechiness,
    required this.acousticness,
    required this.instrumentalness,
    required this.liveness,
    required this.valence,
    required this.tempo,
    required this.timeSignature,
    required this.songID,
  });

  factory SongAudioFeatures.fromMap(Map<String, Object?> map) {
    return SongAudioFeatures(
      id: map['id'] as int,
      danceability: map['danceability'] as double?,
      energy: map['energy'] as double?,
      key: map['key'] as int?,
      loudness: map['loudness'] as double?,
      mode: map['mode'] as int?,
      speechiness: map['speechiness'] as double?,
      acousticness: map['acousticness'] as double?,
      instrumentalness: map['instrumentalness'] as double?,
      liveness: map['liveness'] as double?,
      valence: map['valence'] as double?,
      tempo: map['tempo'] as double?,
      timeSignature: map['timeSignature'] as int?,
      songID: map['song'] as int,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'danceability': danceability,
      'energy': energy,
      'key': key,
      'loudness': loudness,
      'mode': mode,
      'speechiness': speechiness,
      'acousticness': acousticness,
      'instrumentalness': instrumentalness,
      'liveness': liveness,
      'valence': valence,
      'tempo': tempo,
      'timeSignature': timeSignature,
      'song': songID,
    };
  }
}
