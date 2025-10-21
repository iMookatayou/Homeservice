class Note {
  final String id;
  final String title;
  final String body;
  final List<String> tags;
  final String? link;
  final DateTime createdAt;

  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.tags,
    this.link,
    required this.createdAt,
  });

  factory Note.fromJson(Map<String, dynamic> j) {
    return Note(
      id: j['id'] as String,
      title: j['title'] as String,
      body: j['body'] as String,
      tags: (j['tags'] as List).map((e) => e.toString()).toList(),
      link: j['link'] as String?,
      createdAt: DateTime.parse(j['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'tags': tags,
    'link': link,
    'created_at': createdAt.toIso8601String(),
  };
}
