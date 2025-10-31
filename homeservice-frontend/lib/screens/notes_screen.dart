// lib/screens/notes_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../state/notes_provider.dart';
import '../repositories/notes_repository.dart';

// ✅ ใช้ Header แบบเดียวกับหน้าอื่น
import '../widgets/top_nav_bar.dart';
import '../widgets/search_bar_field.dart';
import '../widgets/header_row.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});
  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  static const _QUERY = NotesQuery(limit: 50, offset: 0);

  final _q = TextEditingController();
  final _scroll = ScrollController();

  // ฟิลเตอร์ทั้งหมด (อยู่ในแผงเดียว)
  bool _filtersOpen = false; // เปิด/ปิดทั้งแผง
  _StatusTab _status = _StatusTab.all;
  String? _category; // bills | chores | appointment | general | null
  bool? _pinned; // true | false | null
  String _tag = 'all';

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider(_QUERY));
    const accent = Color(0xFF1F4E9E);

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: accent),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          centerTitle: false,
        ),
        visualDensity: VisualDensity.compact,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: TopNavBar(
          title: 'Important Notes',
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.refresh(notesProvider(_QUERY)),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Clear filters',
              onPressed: _clearAll,
              icon: const Icon(Icons.filter_alt_off),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          onPressed: () => _openEditor(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('New Note'),
        ),
        body: Column(
          children: [
            // ✅ Header เดียวกับหน้าอื่น: Search ทางซ้าย + ปุ่ม Filters ทางขวา
            HeaderRow(
              left: _SearchField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                onClear: () => setState(() {}),
              ),
              right: _FilterButton(
                isOpen: _filtersOpen,
                activeCount: _activeFilterCount(),
                onTap: () => setState(() => _filtersOpen = !_filtersOpen),
              ),
            ),

            // ✅ แผง Filters (กาง/หุบ) — เนื้อหาเหมือนเดิม
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 160),
              crossFadeState: _filtersOpen
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('Status'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            _statusChip('All', _StatusTab.all),
                            _statusChip('Active', _StatusTab.active),
                            _statusChip('Done', _StatusTab.done),
                            _statusChip('Overdue', _StatusTab.overdue),
                            _statusChip('Pinned', _StatusTab.pinned),
                          ],
                        ),
                        const SizedBox(height: 10),

                        _SectionLabel('Category'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            _categoryChip('All', null),
                            _categoryChip('Bills', 'bills'),
                            _categoryChip('Chores', 'chores'),
                            _categoryChip('Appointment', 'appointment'),
                            _categoryChip('General', 'general'),
                          ],
                        ),
                        const SizedBox(height: 10),

                        _SectionLabel('Pinned'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            _pinnedChip('All', null),
                            _pinnedChip('Pinned', true),
                            _pinnedChip('Unpinned', false),
                          ],
                        ),
                        const SizedBox(height: 10),

                        _SectionLabel('Tag'),
                        const SizedBox(height: 6),
                        notes.maybeWhen(
                          data: (items) {
                            final set = <String>{};
                            for (final n in items) set.addAll(n.tags);
                            final list = set.toList()..sort();
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _tagChip('All', 'all'),
                                  const SizedBox(width: 6),
                                  for (final t in list) ...[
                                    _tagChip('#$t', t),
                                    const SizedBox(width: 6),
                                  ],
                                ],
                              ),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 12),
                        Row(
                          children: {
                            TextButton.icon(
                              onPressed: _clearAll,
                              icon: const Icon(Icons.clear_all, size: 18),
                              label: const Text('Clear'),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: accent,
                              ),
                              onPressed: () {
                                setState(() => _filtersOpen = false);
                                _scroll.animateTo(
                                  0,
                                  duration: const Duration(milliseconds: 160),
                                  curve: Curves.easeOut,
                                );
                              },
                              icon: const Icon(Icons.check),
                              label: const Text('Apply'),
                            ),
                          }.toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),

            // ✅ เนื้อหาหลัก (List/Refresh) — เหมือนเดิม
            Expanded(child: _buildBody(notes, accent)),
          ],
        ),
      ),
    );
  }

  // ==== Chips builders ====
  Widget _statusChip(String label, _StatusTab tab) => ChoiceChip(
    label: Text(label),
    selected: _status == tab,
    onSelected: (_) => setState(() => _status = tab),
  );

  Widget _categoryChip(String label, String? v) => ChoiceChip(
    label: Text(label),
    selected: (v == null && (_category == null || _category!.isEmpty))
        ? true
        : _category == v,
    onSelected: (_) => setState(() => _category = v),
  );

  Widget _pinnedChip(String label, bool? v) => ChoiceChip(
    label: Text(label),
    selected: _pinned == v,
    onSelected: (_) => setState(() => _pinned = v),
  );

  Widget _tagChip(String label, String v) => ChoiceChip(
    label: Text(label),
    selected: _tag == v,
    onSelected: (_) => setState(() => _tag = v),
  );

  // ==== Body ====
  Widget _buildBody(AsyncValue<List<Note>> notes, Color accent) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: notes.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.refresh(notesProvider(_QUERY)),
        ),
        data: (items) {
          final filtered = _applyFilters(
            items,
            q: _q.text,
            tag: _tag,
            category: _category,
            pinned: _pinned,
          );
          final byStatus = filtered.where((n) {
            switch (_status) {
              case _StatusTab.all:
                return true;
              case _StatusTab.active:
                return !n.isDone && !n.isOverdue;
              case _StatusTab.done:
                return n.isDone;
              case _StatusTab.overdue:
                return n.isOverdue;
              case _StatusTab.pinned:
                return n.pinned == true;
            }
          }).toList();

          if (byStatus.isEmpty) {
            return const Center(
              child: Text(
                'ไม่พบโน้ตที่ตรงกับเงื่อนไข',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.refresh(notesProvider(_QUERY).future);
            },
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: byStatus.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _NoteCard(
                note: byStatus[i],
                accent: accent,
                onEdit: () => _openEditor(context, ref, note: byStatus[i]),
                onDelete: () => _confirmDelete(context, ref, byStatus[i]),
                onTogglePin: () => _togglePin(ref, byStatus[i]),
                onToggleDone: () => _toggleDone(ref, byStatus[i]),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==== Logic ====
  void _clearAll() {
    setState(() {
      _q.clear();
      _status = _StatusTab.all;
      _category = null;
      _pinned = null;
      _tag = 'all';
      _filtersOpen = false;
    });
  }

  int _activeFilterCount() {
    var c = 0;
    if (_category != null && _category!.isNotEmpty) c++;
    if (_pinned != null) c++;
    if (_tag != 'all') c++;
    if (_q.text.trim().isNotEmpty) c++;
    if (_status != _StatusTab.all) c++; // นับสถานะด้วย
    return c;
  }

  List<Note> _applyFilters(
    List<Note> items, {
    required String q,
    required String tag,
    required String? category,
    required bool? pinned,
  }) {
    Iterable<Note> res = items;

    if (tag != 'all') res = res.where((n) => n.tags.contains(tag));
    if (category != null && category.isNotEmpty) {
      res = res.where((n) => (n.category ?? '').toLowerCase() == category);
    }
    if (pinned != null) res = res.where((n) => (n.pinned ?? false) == pinned);
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
      showDragHandle: true,
      builder: (_) => _EditorSheet(note: note, accent: const Color(0xFF1F4E9E)),
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
          content: result.body,
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

  String _shortError(DioException e, {String fallback = 'Error'}) {
    final sc = e.response?.statusCode;
    if (sc == 401) return '$fallback: 401 (โปรดเข้าสู่ระบบใหม่)';
    if (sc == 404) return '$fallback: 404 (ไม่พบข้อมูล/endpoint)';
    return '$fallback${sc != null ? ' ($sc)' : ''}: ${e.message}';
  }
}

/* ===== Helpers ===== */

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: const Color(0xFF374151),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

enum _StatusTab { all, active, done, overdue, pinned }

extension _NoteComputed on Note {
  bool get isDone => doneAt != null;
  bool get isOverdue =>
      !isDone && dueAt != null && dueAt!.isBefore(DateTime.now());
  bool get isEdited => updatedAt != null && updatedAt!.isAfter(createdAt);
}

/* ===== Search, Card, Editor, Error ===== */

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

  void _listener() => setState(() {});
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
      decoration: InputDecoration(
        hintText: 'ค้นหาโน้ต (หัวข้อ/เนื้อหา/แท็ก)',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close),
                onPressed: () {
                  widget.controller.clear();
                  widget.onClear();
                },
              ),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
        ),
      ),
    );
  }
}

// ปุ่ม Filters ทางขวาใน HeaderRow (แจ้งจำนวน Active + toggle เปิด/ปิด)
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.isOpen,
    required this.activeCount,
    required this.onTap,
  });
  final bool isOpen;
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeCount > 0;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.tune, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Filters'),
          if (hasActive) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$activeCount',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(width: 2),
          Icon(isOpen ? Icons.expand_less : Icons.expand_more, size: 18),
        ],
      ),
    );
  }
}

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

class _NoteCardState extends State<_NoteCard> with TickerProviderStateMixin {
  bool _expanded = false;

  String _previewBody(String body, {int limit = 140}) {
    if (_expanded) return body;
    if (body.length <= limit) return body;
    return body.substring(0, limit).trimRight() + ' …';
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.note;
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final cat = (n.category ?? 'general');
    final editedSuffix = n.isEdited ? ' (edited)' : '';

    final statusPill = n.isDone
        ? const _Pill(
            text: 'DONE',
            color: Color(0xFFE8FFF1),
            textColor: Color(0xFF16A34A),
          )
        : (n.isOverdue
              ? const _Pill(
                  text: 'OVERDUE',
                  color: Color(0xFFFFEEF0),
                  textColor: Color(0xFFDC2626),
                )
              : const _Pill(
                  text: 'ACTIVE',
                  color: Color(0xFFEFF6FF),
                  textColor: Color(0xFF2563EB),
                ));

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${n.title}$editedSuffix',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    df.format(n.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                ],
              ),
              const SizedBox(height: 6),

              // Pills
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  statusPill,
                  const _Pill(
                    text: 'general',
                    color: Color(0xFFF3F4F6),
                    textColor: Color(0xFF374151),
                  ),
                  if (n.tags.isNotEmpty)
                    _Pill(
                      text: '#${n.tags.first}',
                      color: const Color(0xFFEFF6FF),
                      textColor: const Color(0xFF2563EB),
                    ),
                  if (n.pinned == true)
                    const _Pill(
                      text: 'Pinned',
                      color: Color(0xFFEFF4FF),
                      textColor: Color(0xFF2563EB),
                    ),
                ],
              ),

              if (n.body.trim().isNotEmpty) const SizedBox(height: 8),
              if (n.body.trim().isNotEmpty)
                AnimatedSize(
                  duration: const Duration(milliseconds: 140),
                  child: Text(
                    _previewBody(n.body, limit: 140),
                    maxLines: _expanded ? 8 : 3,
                    overflow: _expanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.25,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ),

              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    tooltip: 'คัดลอก',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: '${n.title}\n\n${n.body}'.trim()),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('คัดลอกแล้ว')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  IconButton(
                    tooltip: n.isDone ? 'ยกเลิกเสร็จสิ้น' : 'เสร็จสิ้น',
                    onPressed: widget.onToggleDone,
                    icon: Icon(
                      n.isDone ? Icons.undo : Icons.check_circle_outline,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'pin') widget.onTogglePin();
                      if (v == 'edit') widget.onEdit();
                      if (v == 'delete') widget.onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Text((n.pinned == true) ? 'Unpin' : 'Pin'),
                      ),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz),
                  ),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
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

/* ===== Editor bottom sheet (เดิม) ===== */

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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          top: 8,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              isEdit ? 'Edit note' : 'New note',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 6),
            SwitchListTile(
              value: _pinned,
              onChanged: (v) => setState(() => _pinned = v),
              title: const Text('Pinned'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: widget.accent,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Content (รองรับวางลิงก์รูปจาก Uploads)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: widget.accent),
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
          ],
        ),
      ),
    );
  }
}
