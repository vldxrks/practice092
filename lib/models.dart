class Tag {
  const Tag(
      {this.id,
      required this.name,
      required this.color,
      required this.createdAt});
  final int? id;
  final String name, color;
  final DateTime createdAt;
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'color': color,
        'created_at': createdAt.toUtc().toIso8601String()
      };
  factory Tag.fromMap(Map<String, Object?> m) => Tag(
      id: m['id'] as int,
      name: m['name'] as String,
      color: m['color'] as String,
      createdAt: DateTime.parse(m['created_at'] as String));
}

class Entry {
  const Entry(
      {this.id,
      required this.title,
      required this.content,
      required this.mood,
      required this.createdAt,
      required this.updatedAt,
      this.isFavorite = false,
      this.tags = const []});
  final int? id;
  final String title, content, mood;
  final DateTime createdAt, updatedAt;
  final bool isFavorite;
  final List<Tag> tags;
  int get wordCount =>
      content.trim().isEmpty ? 0 : content.trim().split(RegExp(r'\s+')).length;
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'content': content,
        'mood': mood,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_favorite': isFavorite ? 1 : 0,
        'word_count': wordCount
      };
  factory Entry.fromMap(Map<String, Object?> m, {List<Tag> tags = const []}) =>
      Entry(
          id: m['id'] as int,
          title: m['title'] as String,
          content: m['content'] as String,
          mood: m['mood'] as String,
          createdAt: DateTime.parse(m['created_at'] as String),
          updatedAt: DateTime.parse(m['updated_at'] as String),
          isFavorite: m['is_favorite'] == 1,
          tags: tags);
}
