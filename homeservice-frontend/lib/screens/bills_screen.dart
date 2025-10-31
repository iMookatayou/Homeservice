import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../models/bill.dart';
import '../state/bills_provider.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/search_bar_field.dart';
import '../widgets/header_row.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});
  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  final _q = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _q.text = ref.read(billsQueryProvider);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(billsQueryProvider.notifier).set(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    // sync controller เมื่อ provider เปลี่ยน
    ref.listen<String>(billsQueryProvider, (_, next) {
      if (_q.text != next) _q.text = next;
    });

    final itemsAsync = ref.watch(billsProvider);
    final filter = ref.watch(billsStatusFilterProvider);

    const accent = Color(0xFF1F4E9E);

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: accent),
        visualDensity: VisualDensity.compact,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: TopNavBar(
          title: 'Bills',
          actions: [
            IconButton(
              tooltip: 'Summary',
              onPressed: () => context.push('/bills/summary'),
              icon: const Icon(Icons.insights),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(billsProvider),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          onPressed: () => context.push('/bills/new'),
          icon: const Icon(Icons.add),
          label: const Text('New Bill'),
        ),
        body: Column(
          children: [
            // Header แบบประกอบ: Search ทางซ้าย + Dropdown ทางขวา (เฉพาะ Bills)
            HeaderRow(
              left: SearchBarField(
                controller: _q,
                onChanged: _onQueryChanged,
                onClear: () {
                  _q.clear();
                  ref.read(billsQueryProvider.notifier).clear();
                },
                hintText: 'ค้นหาบิล (หัวข้อ/หมายเหตุ/ประเภท)…',
              ),
              right: DropdownButtonHideUnderline(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: DropdownButton<BillsStatusFilter>(
                      value: filter,
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(billsStatusFilterProvider.notifier).set(v);
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: BillsStatusFilter.all,
                          child: Text('All'),
                        ),
                        DropdownMenuItem(
                          value: BillsStatusFilter.unpaid,
                          child: Text('Unpaid'),
                        ),
                        DropdownMenuItem(
                          value: BillsStatusFilter.paid,
                          child: Text('Paid'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: itemsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e is FormatException ? e.message : e.toString(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () => ref.invalidate(billsProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('ลองอีกครั้ง'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return _EmptyState(
                      onClear: () {
                        _q.clear();
                        ref.read(billsQueryProvider.notifier).clear();
                        ref
                            .read(billsStatusFilterProvider.notifier)
                            .set(BillsStatusFilter.all);
                      },
                      onCreate: () => context.push('/bills/new'),
                    );
                  }
                  return RefreshIndicator.adaptive(
                    onRefresh: () async {
                      await ref.refresh(billsProvider.future);
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _BillCard(
                        bill: items[i],
                        onTap: () => context.push(
                          '/bills/${items[i].id}',
                          extra: items[i],
                        ),
                      ),
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
}

/* -------------------------- Card UI (สองบรรทัดชิป) -------------------------- */

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, this.onTap});
  final Bill bill;
  final VoidCallback? onTap;

  static const _green = Color(0xFF12B76A);
  static const _red = Color(0xFFF04438);
  static const _overdue = Color(0xFFB42318);
  static const _soon = Color(0xFFF79009);

  bool get _isPaid => bill.status == 'paid';

  IconData _iconByType(String t) {
    switch (t) {
      case 'electric':
        return Icons.lightbulb_outline;
      case 'water':
        return Icons.water_drop_outlined;
      case 'internet':
        return Icons.wifi_outlined;
      case 'phone':
        return Icons.phone_iphone;
      default:
        return Icons.receipt_long;
    }
  }

  int _daysDiff(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(today).inDays;
  }

  Color _dueColor(BuildContext ctx, int d) {
    if (_isPaid) return Theme.of(ctx).colorScheme.onSurfaceVariant;
    if (d < 0) return _overdue;
    if (d <= 3) return _soon;
    return Theme.of(ctx).colorScheme.onSurfaceVariant;
  }

  String _dueText(DateTime dueDate) {
    final d = _daysDiff(dueDate);
    final fmt = DateFormat('d MMM yyyy');
    if (_isPaid) return 'Paid on ${fmt.format(dueDate)}';
    if (d == 0) return 'Due today';
    if (d == 1) return 'Due tomorrow';
    if (d > 1 && d <= 7) return 'Due in $d days';
    if (d < 0) return '${-d} day${d == -1 ? '' : 's'} late';
    return 'Due ${fmt.format(dueDate)}';
  }

  Widget _chip(
    BuildContext context, {
    required Widget child,
    Color? fg,
    Color? bg,
    Color? border,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? cs.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border ?? cs.outlineVariant),
      ),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.labelMedium!.copyWith(
          color: fg ?? cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [child]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final money = NumberFormat.currency(locale: 'th_TH', symbol: '฿');
    final d = _daysDiff(bill.dueDate);

    final statusFg = _isPaid ? _green : _red;
    final statusBg = statusFg.withOpacity(0.12);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bill.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    money.format(bill.amount),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 2),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _chip(
                    context,
                    fg: statusFg,
                    bg: statusBg,
                    border: statusFg.withOpacity(0.35),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPaid
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 14,
                          color: statusFg,
                        ),
                        const SizedBox(width: 6),
                        Text(_isPaid ? 'ชำระแล้ว' : 'ยังไม่ชำระ'),
                      ],
                    ),
                  ),
                  _chip(
                    context,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_iconByType(bill.type), size: 14),
                        const SizedBox(width: 6),
                        Text(bill.type),
                      ],
                    ),
                  ),
                  _chip(
                    context,
                    fg: _dueColor(context, d),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          d < 0 ? Icons.error_outline : Icons.schedule,
                          size: 14,
                          color: _dueColor(context, d),
                        ),
                        const SizedBox(width: 6),
                        Text(_dueText(bill.dueDate)),
                      ],
                    ),
                  ),
                ],
              ),
              if ((bill.note ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  bill.note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------- Empty state ------------------------------- */

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onClear, required this.onCreate});
  final VoidCallback onClear;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text('ยังไม่มีบิล', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'เพิ่มบิลใหม่ หรือเคลียร์ตัวกรอง/คำค้นหา',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Clear filters'),
                ),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('New Bill'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
