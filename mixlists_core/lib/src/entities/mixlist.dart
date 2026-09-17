class Mixlist {
  final int id;
  final String title;
  final String description;
  final String dateCreated;

  Mixlist({
    required this.id,
    required this.title,
    required this.description,
    required this.dateCreated,
  });

  factory Mixlist.fromMap(Map<String, Object?> map) {
    return Mixlist(
      id: map['id'] as int,
      title: map['title'] as String,
      description: map['description'] as String,
      dateCreated: map['dateCreated'] as String,
    );
  }
 
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dateCreated': dateCreated,
    };
  }

}
