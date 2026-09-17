class SongMixlist {
  final int id;
  final int position;
  final String dateAdded;
  final int songID;
  final int mixlistID;

  SongMixlist({
    required this.id,
    required this.position,
    required this.dateAdded,
    required this.songID,
    required this.mixlistID,
  });

  factory SongMixlist.fromMap(Map<String, Object?> map) {
    return SongMixlist(
      id: map['id'] as int,
      position: map['positionIndex'] as int, // stores order of songs
      dateAdded: map['dateAdded'] as String,
      songID: map['song'] as int,
      mixlistID: map['mixlist'] as int,
    );
  }
 
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'positionIndex': position,
      'dateAdded': dateAdded,
      'song': songID,
      'mixlist': mixlistID,
    };
  }

}
