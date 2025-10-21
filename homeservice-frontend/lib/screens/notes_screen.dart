import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../state/notes_provider.dart';
import '../models/note.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});
  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _q = TextEditingController();
  String _activeTag = 'all';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Important Notes'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    decoration: InputDecoration(
                      hintText: 'ค้นหาโน้ต (เช่น uploads, trigger, jwt)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  tooltip: 'Filter by tag',
                  onSelected: (v) => setState(() => _activeTag = v),
                  itemBuilder: (ctx) {
                    final all =
                        notes
                            .maybeWhen(
                              data: _collectTags,
                              orElse: () => <String>{},
                            )
                            .toList()
                          ..sort();
                    return [
                      const PopupMenuItem(
                        value: 'all',
                        child: Text('All tags'),
                      ),
                      ...all.map(
                        (t) => PopupMenuItem(value: t, child: Text('#$t')),
                      ),
                    ];
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE7ECF4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list),
                        const SizedBox(width: 6),
                        Text(_activeTag == 'all' ? 'All tags' : '#$_activeTag'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: notes.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (items) {
                  final filtered = _applyFilters(items, _q.text, _activeTag);
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('ไม่พบโน้ตที่ตรงกับเงื่อนไข'),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      // เรียก read.refresh เพื่อรีโหลด FutureProvider
                      await ref.refresh(notesProvider.future);
                    },
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) => _NoteCard(note: filtered[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Note> _applyFilters(List<Note> items, String q, String tag) {
    Iterable<Note> res = items;
    if (tag != 'all') {
      res = res.where((n) => n.tags.contains(tag));
    }
    if (q.trim().isNotEmpty) {
      final k = q.toLowerCase();
      res = res.where(
        (n) =>
            n.title.toLowerCase().contains(k) ||
            n.body.toLowerCase().contains(k) ||
            n.tags.any((t) => t.toLowerCase().contains(k)),
      );
    }
    return res.toList();
  }

  Set<String> _collectTags(List<Note> items) {
    final s = <String>{};
    for (final n in items) {
      s.addAll(n.tags);
    }
    return s;
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE7ECF4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  df.format(note.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              note.body,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: -6,
              children: note.tags
                  .map(
                    (t) => Chip(
                      label: Text('#$t'),
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: Color(0xFFE7ECF4)),
                      backgroundColor: Colors.white,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final text = '${note.title}\n\n${note.body}';
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('คัดลอกโน้ตแล้ว')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('คัดลอก'),
                ),
                const SizedBox(width: 8),
                if (note.link != null && note.link!.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('เปิดลิงก์: ${note.link}')),
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('เปิดลิงก์'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
