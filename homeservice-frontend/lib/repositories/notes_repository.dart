// lib/repositories/notes_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../services/api_client.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final api = ref.read(apiClientProvider);
  return NotesRepository(api);
});

class NotesRepository {
  NotesRepository(this.api);
  final ApiClient api;

  // ===== List =====
  Future<List<Note>> list({
    String? q,
    String? category,
    bool? pinned,
    String? status, // 'active' | 'done'
    String? assignedTo,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async {
    final res = await api.getV1<dynamic>(
      '/notes',
      query: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (category != null && category.isNotEmpty) 'category': category,
        if (pinned != null) 'pinned': pinned.toString(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (assignedTo != null && assignedTo.isNotEmpty)
          'assigned_to': assignedTo,
        'limit': limit,
        'offset': offset,
      },
      cancelToken: cancelToken,
    );

    final payload = res.data;
    List listJson;
    if (payload is List) {
      listJson = payload;
    } else if (payload is Map && payload['data'] is List) {
      listJson = payload['data'] as List;
    } else {
      listJson = const [];
    }

    return listJson
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .map(Note.fromJson)
        .toList();
  }

  // ===== Get one =====
  Future<Note> getById(String id, {CancelToken? cancelToken}) async {
    final res = await api.getV1<dynamic>(
      '/notes/$id',
      cancelToken: cancelToken,
    );
    final Map<String, dynamic> j = (res.data as Map).cast<String, dynamic>();
    return Note.fromJson(j);
  }

  // ===== Create =====
  Future<Note> create({
    required String title,
    String? content,
    String category = 'general',
    bool pinned = false,
    String? assignedTo,
    DateTime? dueAt,
    DateTime? remindAt,
    int? priority,
    String? location,
    CancelToken? cancelToken,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      if (content != null) 'content': content,
      'category': category,
      'pinned': pinned,
      if (assignedTo != null) 'assigned_to': assignedTo,
      if (dueAt != null) 'due_at': dueAt.toIso8601String(),
      if (remindAt != null) 'remind_at': remindAt.toIso8601String(),
      if (priority != null) 'priority': priority,
      if (location != null) 'location': location,
    };

    final res = await api.postV1<dynamic>(
      '/notes',
      data: body,
      cancelToken: cancelToken,
    );
    final Map<String, dynamic> j = (res.data as Map).cast<String, dynamic>();
    return Note.fromJson(j);
  }

  // ===== Update (partial) =====
  Future<Note> update({
    required String id,
    String? title,
    String? content, // ส่ง "" เพื่อล้าง
    String? category,
    bool? pinned,
    String? assignedTo,
    DateTime? dueAt,
    DateTime? remindAt,
    int? priority,
    String? location,
    bool? clearDueAt,
    bool? clearRemindAt,
    bool? clearLocation,
    CancelToken? cancelToken,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (content != null) body['content'] = content;
    if (category != null) body['category'] = category;
    if (pinned != null) body['pinned'] = pinned;
    if (assignedTo != null) body['assigned_to'] = assignedTo;
    if (dueAt != null) body['due_at'] = dueAt.toIso8601String();
    if (remindAt != null) body['remind_at'] = remindAt.toIso8601String();
    if (priority != null) body['priority'] = priority;
    if (location != null) body['location'] = location;
    if (clearDueAt == true) body['due_at'] = null;
    if (clearRemindAt == true) body['remind_at'] = null;
    if (clearLocation == true) body['location'] = null;

    // Backend ใช้ PUT /
    final res = await api.putV1<dynamic>(
      '/notes/$id',
      data: body,
      cancelToken: cancelToken,
    );
    final Map<String, dynamic> j = (res.data as Map).cast<String, dynamic>();
    return Note.fromJson(j);
  }

  // ===== Delete =====
  Future<void> delete(String id, {CancelToken? cancelToken}) async {
    await api.deleteV1<void>('/notes/$id', cancelToken: cancelToken);
  }

  // ===== Pin / Unpin (POST) =====
  Future<Note> setPinned(
    String id,
    bool set, {
    CancelToken? cancelToken,
  }) async {
    final path = set ? '/notes/$id/pin' : '/notes/$id/unpin';
    final res = await api.postV1<dynamic>(path, cancelToken: cancelToken);
    final Map<String, dynamic> j = (res.data as Map).cast<String, dynamic>();
    return Note.fromJson(j);
  }

  // ===== Done / Undone (POST) =====
  Future<Note> setDone(String id, {CancelToken? cancelToken}) async {
    final res = await api.postV1<dynamic>(
      '/notes/$id/done',
      cancelToken: cancelToken,
    );
    final Map<String, dynamic> j = (res.data as Map).cast<String, dynamic>();
    return Note.fromJson(j);
  }

  Future<Note> unsetDone(String id, {CancelToken? cancelToken}) async {
    final res = await api.postV1<dynamic>(
      '/notes/$id/undone',
      cancelToken: cancelToken,
    );
    final Map<String, dynamic> j = (res.data as Map).cast<String, dynamic>();
    return Note.fromJson(j);
  }

  // ===== Upload image =====
  Future<String> uploadImage(
    MultipartFile file, {
    CancelToken? cancelToken,
  }) async {
    final form = FormData.fromMap({'file': file});
    final res = await api.postV1<dynamic>(
      '/uploads',
      data: form,
      cancelToken: cancelToken,
    );
    final map = (res.data as Map).cast<String, dynamic>();
    return (map['url'] as String?) ??
        (map['file_url'] as String?) ??
        map['id']?.toString() ??
        '';
  }
}
