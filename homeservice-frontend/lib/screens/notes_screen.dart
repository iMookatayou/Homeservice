// lib/screens/notes_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../state/notes_provider.dart';
import '../repositories/notes_repository.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});
  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  // ใช้ instance เดียวของ query ให้ทุกจุดอ้างอิงตัวเดียวกัน
  static const _QUERY = NotesQuery(limit: 50, offset: 0);

  final _q = TextEditingController();
  String _activeTag = 'all';
  String? _activeCategory; // bills | chores | appointment | general | null
  bool? _activePinned; // true | false | null
  final _scroll = ScrollController();

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider(_QUERY));
    final accent = const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add note'),
        onPressed: () => _openEditor(context, ref),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          // Header: gradient + title + subtitle + search
          _NotesHeaderBar(
            accent: accent,
            title: 'Important Notes',
            subtitle: notes.maybeWhen(
              data: (items) => '${items.length} notes • synced',
              orElse: () => 'Loading…',
            ),
            qController: _q,
            onSearchChanged: (_) => setState(() {}), // filter realtime
            onBack: () => Navigator.maybePop(context),
            // ต้อง refresh ที่ instance ของ family เสมอ
            onRefresh: () => ref.refresh(notesProvider(_QUERY)),
            onClearFilters: () {
              setState(() {
                _q.clear();
                _activeTag = 'all';
                _activeCategory = null;
                _activePinned = null;
              });
            },
          ),

          // Sticky filters bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _FiltersHeaderDelegate(
              minExtent: 64,
              maxExtent: 64,
              child: _FiltersBar(
                background: Colors.white,
                category: _activeCategory,
                onCategory: (v) {
                  setState(() => _activeCategory = v);
                  _scroll.animateTo(
                    0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                },
                pinned: _activePinned,
                onPinned: (v) {
                  setState(() => _activePinned = v);
                  _scroll.animateTo(
                    0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                },
                tagWidget: _TagFilter(
                  tags: notes.maybeWhen(
                    data: (items) {
                      final s = <String>{};
                      for (final n in items) s.addAll(n.tags);
                      final list = s.toList()..sort();
                      return list;
                    },
                    orElse: () => <String>[],
                  ),
                  activeTag: _activeTag,
                  onChanged: (v) {
                    setState(() => _activeTag = v);
                    _scroll.animateTo(
                      0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
        body: _buildBody(notes, accent),
      ),
    );
  }

  // ===== Body =====
  Widget _buildBody(AsyncValue<List<Note>> notes, Color accent) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: '$e',
          // refresh ต้องชี้ instance
          onRetry: () => ref.refresh(notesProvider(_QUERY)),
        ),
        data: (items) {
          final filtered = _applyFilters(
            items,
            q: _q.text,
            tag: _activeTag,
            category: _activeCategory,
            pinned: _activePinned,
          );
          if (filtered.isEmpty) {
            return const Center(child: Text('ไม่พบโน้ตที่ตรงกับเงื่อนไข'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              await ref.refresh(notesProvider(_QUERY).future);
            },
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _NoteCard(
                note: filtered[i],
                accent: accent,
                onEdit: () => _openEditor(context, ref, note: filtered[i]),
                onDelete: () => _confirmDelete(context, ref, filtered[i]),
                onTogglePin: () => _togglePin(ref, filtered[i]),
                onToggleDone: () => _toggleDone(ref, filtered[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===== Filtering =====
  List<Note> _applyFilters(
    List<Note> items, {
    required String q,
    required String tag,
    required String? category,
    required bool? pinned,
  }) {
    Iterable<Note> res = items;

    if (tag != 'all') {
      res = res.where((n) => n.tags.contains(tag));
    }
    if (category != null && category.isNotEmpty) {
      res = res.where((n) => (n.category ?? '').toLowerCase() == category);
    }
    if (pinned != null) {
      res = res.where((n) => (n.pinned ?? false) == pinned);
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

  // ===== Actions =====
  Future<void> _toggleDone(WidgetRef ref, Note note) async {
    final repo = ref.read(notesRepositoryProvider);
    final isDone = note.doneAt != null;

    try {
      final updated = isDone
          ? await repo.unsetDone(note.id)
          : await repo.setDone(note.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.doneAt != null ? 'ทำเสร็จแล้ว' : 'ยกเลิกเสร็จสิ้นแล้ว',
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_shortError(e, fallback: 'Done error'))),
      );
    } finally {
      // invalidate ต้องชี้ instance
      ref.invalidate(notesProvider(_QUERY));
    }
  }

  Future<void> _togglePin(WidgetRef ref, Note note) async {
    final repo = ref.read(notesRepositoryProvider);
    try {
      final toggled = await repo.setPinned(note.id, !(note.pinned ?? false));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(toggled.pinned == true ? 'Pinned' : 'Unpinned'),
          ),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_shortError(e, fallback: 'Pin error'))),
      );
    } finally {
      ref.invalidate(notesProvider(_QUERY));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note'),
        content: Text('ลบ "${note.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(notesRepositoryProvider).delete(note.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบแล้ว')));
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_shortError(e, fallback: 'Delete error'))),
      );
    } finally {
      ref.invalidate(notesProvider(_QUERY));
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    Note? note,
  }) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditorSheet(note: note, accent: _blue(context)),
    );

    if (result == null) return;

    final repo = ref.read(notesRepositoryProvider);
    final cancel = CancelToken();

    try {
      if (note == null) {
        await repo.create(
          title: result.title,
          content: result.body.isEmpty ? null : result.body,
          category: result.category,
          pinned: result.pinned,
          cancelToken: cancel,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('เพิ่มโน้ตแล้ว')));
        }
      } else {
        await repo.update(
          id: note.id,
          title: result.title,
          content: result.body, // ส่ง "" เพื่อล้างได้
          category: result.category,
          pinned: result.pinned,
          cancelToken: cancel,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('แก้ไขโน้ตแล้ว')));
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_shortError(e, fallback: 'Save error'))),
      );
    } finally {
      ref.invalidate(notesProvider(_QUERY));
    }
  }

  // ---- helpers ----
  String _shortError(DioException e, {String fallback = 'Error'}) {
    final sc = e.response?.statusCode;
    if (sc == 401) return '$fallback: 401 (โปรดเข้าสู่ระบบใหม่)';
    if (sc == 404) return '$fallback: 404 (ไม่พบข้อมูล/endpoint)';
    return '$fallback${sc != null ? ' ($sc)' : ''}: ${e.message}';
  }

  Color _blue(BuildContext context) => const Color(0xFF2563EB);
}

// ===================== Cards & misc =====================

class _NoteCard extends StatefulWidget {
  const _NoteCard({
    required this.note,
    required this.accent,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
    required this.onToggleDone,
  });

  final Note note;
  final Color accent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleDone;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _expanded = false;

  // ดึง URL รูปภาพอันแรกจาก body (รองรับ .jpg/.jpeg/.png/.gif)
  String? _firstImageUrl(String text) {
    final re = RegExp(
      r'(https?:\/\/[^\s)]+?\.(?:png|jpg|jpeg|gif))',
      caseSensitive: false,
    );
    final m = re.firstMatch(text);
    return m?.group(0);
  }

  // ตัดข้อความให้เป็น preview ถ้ายังไม่กดขยาย
  String _previewBody(String body, {int limit = 220}) {
    if (_expanded) return body;
    if (body.length <= limit) return body;
    return body.substring(0, limit).trimRight() + ' …';
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final pinned = note.pinned == true;
    final cat = (note.category ?? 'general').toUpperCase();

    final bool isDone = note.doneAt != null;
    final bool isOverdue =
        !isDone && note.dueAt != null && note.dueAt!.isBefore(DateTime.now());

    final body = note.body;
    final img = _firstImageUrl(body);

    return Opacity(
      opacity: isDone ? 0.75 : 1,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header line ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (pinned)
                          const Icon(
                            Icons.push_pin,
                            size: 18,
                            color: Color(0xFF2563EB),
                          ),
                        Text(
                          note.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        _Pill(
                          text: cat,
                          color: const Color(0xFFEFF4FF),
                          textColor: const Color(0xFF2563EB),
                        ),
                        if (isDone)
                          const _Pill(
                            text: 'DONE',
                            color: Color(0xFFE8FFF1),
                            textColor: Color(0xFF16A34A),
                          ),
                        if (isOverdue)
                          const _Pill(
                            text: 'OVERDUE',
                            color: Color(0xFFFFEEF0),
                            textColor: Color(0xFFDC2626),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      df.format(note.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Content (body) ──
              if (body.trim().isNotEmpty) const SizedBox(height: 10),
              if (body.trim().isNotEmpty)
                Text(
                  _previewBody(body),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                    color: const Color(0xFF374151),
                  ),
                ),

              // ── Image preview (ถ้ามีลิงก์รูปใน body) ──
              if (img != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    img,
                    fit: BoxFit.cover,
                    // กันกระตุกเล็กน้อยระหว่างโหลด
                    loadingBuilder: (ctx, child, ev) {
                      if (ev == null) return child;
                      return Container(
                        height: 160,
                        alignment: Alignment.center,
                        color: const Color(0xFFF3F4F6),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('รูปโหลดไม่สำเร็จ'),
                    ),
                  ),
                ),
              ],

              // ── Read more / less ──
              if (body.length > 220) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    label: Text(_expanded ? 'Show less' : 'Read more'),
                  ),
                ),
              ],

              const SizedBox(height: 4),

              // ── Actions ──
              LayoutBuilder(
                builder: (ctx, c) {
                  final left = Wrap(
                    spacing: 8,
                    runSpacing: -6,
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
                      TextButton.icon(
                        onPressed: widget.onToggleDone,
                        icon: Icon(
                          isDone ? Icons.undo : Icons.check_circle_outline,
                        ),
                        label: Text(isDone ? 'ยกเลิกเสร็จสิ้น' : 'เสร็จสิ้น'),
                      ),
                    ],
                  );

                  final right = Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: pinned ? 'Unpin' : 'Pin',
                        onPressed: widget.onTogglePin,
                        icon: Icon(
                          pinned ? Icons.push_pin : Icons.push_pin_outlined,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit, color: Color(0xFF2563EB)),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: widget.onDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  );

                  return c.maxWidth > 360
                      ? Row(children: [left, const Spacer(), right])
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            left,
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: right,
                            ),
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
    required this.textColor,
  });
  final String text;
  final Color color;
  final Color textColor;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ===================== Editor bottom sheet =====================

class _EditorSheet extends StatefulWidget {
  const _EditorSheet({this.note, required this.accent});
  final Note? note;
  final Color accent;

  @override
  State<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<_EditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late String _category;
  late bool _pinned;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = TextEditingController(text: widget.note?.body ?? '');
    _category = (widget.note?.category ?? 'general').toLowerCase();
    _pinned = widget.note?.pinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.note != null;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.6,
      builder: (ctx, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.black.withOpacity(0.12),
                  ),
                ),
              ),
              Text(
                isEdit ? 'Edit note' : 'New note',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                items: const [
                  DropdownMenuItem(value: 'general', child: Text('General')),
                  DropdownMenuItem(value: 'bills', child: Text('Bills')),
                  DropdownMenuItem(value: 'chores', child: Text('Chores')),
                  DropdownMenuItem(
                    value: 'appointment',
                    child: Text('Appointment'),
                  ),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'general'),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _pinned,
                onChanged: (v) => setState(() => _pinned = v),
                title: const Text('Pinned'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: widget.accent,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Content (รองรับแปะลิงก์รูปจาก Uploads)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.accent,
                    ),
                    onPressed: () {
                      final title = _title.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('กรุณากรอก Title')),
                        );
                        return;
                      }
                      Navigator.pop(
                        context,
                        _EditResult(
                          title: title,
                          body: _body.text,
                          category: _category,
                          pinned: _pinned,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check),
                    label: Text(isEdit ? 'Save' : 'Create'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Tip(accent: widget.accent),
            ],
          ),
        );
      },
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.accent});
  final Color accent;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDBE4FF)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: accent),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'แนบรูปได้โดยอัปโหลดในเมนู Uploads แล้วคัดลอกลิงก์มาแปะใน Content',
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Header (gradient + search) =====================

class _NotesHeaderBar extends StatelessWidget {
  const _NotesHeaderBar({
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.qController,
    required this.onSearchChanged,
    required this.onBack,
    required this.onRefresh,
    required this.onClearFilters,
  });

  final Color accent;
  final String title;
  final String subtitle;
  final TextEditingController qController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      stretch: true,
      expandedHeight: 192, // ขยายขึ้นนิดนึงให้พอดี
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, const Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─────── top row ───────
                Row(
                  children: [
                    _CircleBtn(
                      icon: Icons.arrow_back,
                      onTap: onBack,
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CircleBtn(
                      icon: Icons.refresh,
                      onTap: onRefresh,
                      tooltip: 'Refresh',
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      color: Colors.white,
                      onSelected: (v) {
                        if (v == 'clear_filters') onClearFilters();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'clear_filters',
                          child: Text('Clear filters'),
                        ),
                      ],
                      icon: const Icon(Icons.more_horiz, color: Colors.white),
                    ),
                  ],
                ),

                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.92),
                  ),
                ),

                const SizedBox(height: 10),
                // ─────── search field ───────
                _SearchField(
                  controller: qController,
                  onChanged: onSearchChanged,
                  onClear: () => onSearchChanged(qController.text),
                ),

                // ─────── เพิ่มข้อความอธิบาย/เนื้อหาด้านล่าง ───────
                const SizedBox(height: 10),
                Text(
                  'คุณสามารถค้นหาโน้ตได้ทั้งจากหัวข้อ เนื้อหา หรือแท็กที่เกี่ยวข้อง',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_listener);
  }

  void _listener() => setState(() {}); // show/hide clear icon

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: 'ค้นหาโน้ต (หัวข้อ/เนื้อหา/แท็ก)',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.85)),
        prefixIcon: const Icon(Icons.search, color: Colors.white),
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  widget.controller.clear();
                  widget.onClear();
                },
              ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.14),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.45)),
        ),
      ),
    );
  }
}

// ---------- Filters sticky bar ----------
class _FiltersHeaderDelegate extends SliverPersistentHeaderDelegate {
  _FiltersHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.child,
  });

  @override
  final double minExtent;
  @override
  final double maxExtent;
  final Widget child;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 2 : 0,
      color: Colors.white,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _FiltersHeaderDelegate oldDelegate) =>
      oldDelegate.minExtent != minExtent ||
      oldDelegate.maxExtent != maxExtent ||
      oldDelegate.child != child;
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.background,
    required this.category,
    required this.onCategory,
    required this.pinned,
    required this.onPinned,
    required this.tagWidget,
  });

  final Color background;
  final String? category;
  final ValueChanged<String?> onCategory;
  final bool? pinned;
  final ValueChanged<bool?> onPinned;
  final Widget tagWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: background,
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            SizedBox(
              width: 180,
              child: _CategoryFilter(value: category, onChanged: onCategory),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 150,
              child: _PinnedFilter(value: pinned, onChanged: onPinned),
            ),
            const SizedBox(width: 8),
            tagWidget,
          ],
        ),
      ),
    );
  }
}

// ===================== Filters widgets =====================

class _TagFilter extends StatelessWidget {
  const _TagFilter({
    required this.tags,
    required this.activeTag,
    required this.onChanged,
  });

  final List<String> tags;
  final String activeTag;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Filter by tag',
      onSelected: onChanged,
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'all', child: Text('All tags')),
        ...tags.map((t) => PopupMenuItem(value: t, child: Text('#$t'))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.35)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              activeTag == 'all' ? 'All tags' : '#$activeTag',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = <DropdownMenuItem<String?>>[
      DropdownMenuItem(value: null, child: Text('All categories')),
      DropdownMenuItem(value: 'bills', child: Text('Bills')),
      DropdownMenuItem(value: 'chores', child: Text('Chores')),
      DropdownMenuItem(value: 'appointment', child: Text('Appointment')),
      DropdownMenuItem(value: 'general', child: Text('General')),
    ];
    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }
}

class _PinnedFilter extends StatelessWidget {
  const _PinnedFilter({required this.value, required this.onChanged});
  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.35)),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<bool?>(
          value: value,
          isExpanded: true,
          onChanged: onChanged,
          items: const [
            DropdownMenuItem(value: null, child: Text('All')),
            DropdownMenuItem(value: true, child: Text('Pinned')),
            DropdownMenuItem(value: false, child: Text('Unpinned')),
          ],
        ),
      ),
    );
  }
}

// ===================== (Optional) Unused but kept helpers =====================

class _HeaderFlexible extends StatelessWidget {
  const _HeaderFlexible({
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.topChild,
    required this.bottomChild,
  });

  final Color accent;
  final String title;
  final String subtitle;
  final Widget topChild;
  final Widget bottomChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, const Color(0xFF3B82F6)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 12),
              topChild,
              const SizedBox(height: 12),
              bottomChild,
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderChipsRow extends StatelessWidget {
  const _HeaderChipsRow({
    required this.tagWidget,
    required this.left,
    required this.right,
  });
  final Widget tagWidget;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
        const SizedBox(width: 12),
        tagWidget,
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _RoundMore extends StatelessWidget {
  const _RoundMore({required this.onSelected});
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'clear_filters', child: Text('Clear filters')),
      ],
      icon: const Icon(Icons.more_horiz, color: Colors.white),
    );
  }
}

// ===================== Models =====================

class _EditResult {
  _EditResult({
    required this.title,
    required this.body,
    required this.category,
    required this.pinned,
  });
  final String title;
  final String body;
  final String category;
  final bool pinned;
}
