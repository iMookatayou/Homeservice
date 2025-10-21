import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../repositories/notes_repository.dart';

final notesProvider = FutureProvider<List<Note>>((ref) async {
  final repo = ref.read(notesRepositoryProvider);
  return repo.list();
});
