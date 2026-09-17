class Mixlist {
  final int id;
  final String title;
  final String description;
  final String dateCreated;

  /// Whether the user has marked this as one of their curated "mixlists"
  /// rather than just any Spotify playlist that happened to get imported
  /// (schema v5's `is_mixlists` column). Defaults to false for anything
  /// not yet explicitly marked.
  final bool isMixlist;

  Mixlist({
    required this.id,
    required this.title,
    required this.description,
    required this.dateCreated,
    this.isMixlist = false,
  });

  factory Mixlist.fromMap(Map<String, Object?> map) {
    return Mixlist(
      id: map['id'] as int,
      title: map['title'] as String,
      description: map['description'] as String,
      dateCreated: map['dateCreated'] as String,
      isMixlist: (map['is_mixlists'] as int?) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateCreated': dateCreated,
      'is_mixlists': isMixlist ? 1 : 0,
    };
  }

}
