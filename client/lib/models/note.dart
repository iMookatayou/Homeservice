// lib/models/note.dart
class Note {
  final String id;
  final String title; // หัวข้อจริง
  final String body; // เนื้อหา (มาจาก content)
  final String? category;
  final List<String> tags;
  final bool? pinned;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? dueAt;
  final DateTime? doneAt;

  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.updatedAt,
    this.category,
    this.tags = const [],
    this.pinned,
    this.dueAt,
    this.doneAt,
  });

  factory Note.fromJson(Map<String, dynamic> j) => Note(
    id: j['id'] as String,
    title: (j['title'] ?? '').toString(),
    body: (j['content'] ?? j['body'] ?? '').toString(),
    category: (j['category'] as String?)?.toLowerCase(),
    tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    pinned: j['pinned'] as bool?,
    createdAt: DateTime.parse(j['created_at']),
    updatedAt: j['updated_at'] != null ? DateTime.parse(j['updated_at']) : null,
    dueAt: j['due_at'] != null ? DateTime.parse(j['due_at']) : null,
    doneAt: j['done_at'] != null ? DateTime.parse(j['done_at']) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': body,
    'category': category,
    'tags': tags,
    'pinned': pinned,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'due_at': dueAt?.toIso8601String(),
    'done_at': doneAt?.toIso8601String(),
  };
}
