// lib/screens/purchase_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../state/purchase_providers.dart';
import '../models/purchase_model.dart';
import '../services/purchase_api.dart';

// ✅ ใช้หัวแบบเดียวกับ Bills/Notes
import '../widgets/top_nav_bar.dart';
import '../widgets/search_bar_field.dart';
import '../widgets/header_row.dart';

enum _StatusFilter { all, planned, ordered, bought, delivered, canceled }

class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});
  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  final _search = TextEditingController();

  // แผงฟิลเตอร์ (pattern เดียวกับ Notes)
  bool _filtersOpen = false;
  _StatusFilter _status = _StatusFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _activeFilterCount() {
    var c = 0;
    if (_status != _StatusFilter.all) c++;
    if (_search.text.trim().isNotEmpty) c++;
    return c;
  }

  void _clearAll() {
    setState(() {
      _status = _StatusFilter.all;
      _search.clear();
      _filtersOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(purchasesListProvider);
    const accent = Color(0xFF1F4E9E); // same tone as Notes

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: accent),
        visualDensity: VisualDensity.compact,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: TopNavBar(
          title: 'Purchases',
          actions: [
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
          onPressed: () => context.push('/purchases/new'),
          icon: const Icon(Icons.add),
          label: const Text('New Purchase'),
        ),
        body: listAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => _ErrorOrAuth(e: e),
          data: (items) => Column(
            children: [
              HeaderRow(
                left: SearchBarField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(_search.clear),
                  hintText:
                      'Search (title/store/category/note/status) • ค้นหา…',
                ),
                right: _FilterButton(
                  isOpen: _filtersOpen,
                  activeCount: _activeFilterCount(),
                  onTap: () => setState(() => _filtersOpen = !_filtersOpen),
                ),
              ),

              AnimatedCrossFade(
                duration: const Duration(milliseconds: 160),
                crossFadeState: _filtersOpen
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.black.withOpacity(.06)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('Status • สถานะ'),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              _statusChip('All • ทั้งหมด', _StatusFilter.all),
                              _statusChip(
                                'Planned • วางแผน',
                                _StatusFilter.planned,
                              ),
                              _statusChip(
                                'Ordered • สั่งแล้ว',
                                _StatusFilter.ordered,
                              ),
                              _statusChip(
                                'Bought • ซื้อแล้ว',
                                _StatusFilter.bought,
                              ),
                              _statusChip(
                                'Delivered • ส่งมอบ',
                                _StatusFilter.delivered,
                              ),
                              _statusChip(
                                'Canceled • ยกเลิก',
                                _StatusFilter.canceled,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _clearAll,
                                icon: const Icon(Icons.clear_all, size: 18),
                                label: const Text('Clear • ล้างทั้งหมด'),
                              ),
                              const Spacer(),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                ),
                                onPressed: () =>
                                    setState(() => _filtersOpen = false),
                                icon: const Icon(Icons.check),
                                label: const Text('Apply • ใช้งาน'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                secondChild: const SizedBox.shrink(),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(purchasesListProvider.future),
                  child: ListView(
                    children: [
                      _ListBody(
                        items: items,
                        q: _search.text,
                        status: _status,
                        onClearFilters: _clearAll,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String label, _StatusFilter v) => ChoiceChip(
    label: Text(label),
    selected: _status == v,
    onSelected: (_) => setState(() => _status = v),
  );
}

/* ===================== Filter Button (เหมือน Notes) ===================== */

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
          const Text('Filters • ตัวกรอง'),
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

/* ===================== List / Cards ===================== */

class _ListBody extends StatelessWidget {
  final List<Purchase> items;
  final String q;
  final _StatusFilter status;
  final VoidCallback onClearFilters;

  const _ListBody({
    required this.items,
    required this.q,
    required this.status,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    Iterable<Purchase> filtered = items.where((p) {
      switch (status) {
        case _StatusFilter.all:
          return true;
        case _StatusFilter.planned:
          return p.status == PurchaseStatus.planned;
        case _StatusFilter.ordered:
          return p.status == PurchaseStatus.ordered;
        case _StatusFilter.bought:
          return p.status == PurchaseStatus.bought;
        case _StatusFilter.delivered:
          return p.status == PurchaseStatus.delivered;
        case _StatusFilter.canceled:
          return p.status == PurchaseStatus.canceled ||
              p.status == PurchaseStatus.cancelled;
      }
    });

    final query = q.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((p) {
        final hay = [
          p.title,
          p.category ?? '',
          p.store ?? '',
          p.note ?? '',
          p.status.name,
        ].join(' ').toLowerCase();
        return hay.contains(query);
      });
    }

    final list = filtered.toList();
    if (list.isEmpty) {
      final hasQueryOrFilter = query.isNotEmpty || status != _StatusFilter.all;
      return _EmptyState(
        hasQueryOrFilter: hasQueryOrFilter,
        onClearFilters: hasQueryOrFilter ? onClearFilters : null,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _PurchaseCard(p: list[i]),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final Purchase p;
  const _PurchaseCard({required this.p});

  Color _statusBg(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    switch (p.status) {
      case PurchaseStatus.planned:
        return cs.surfaceVariant;
      case PurchaseStatus.ordered:
        return Colors.blue.withOpacity(.12);
      case PurchaseStatus.bought:
        return Colors.amber.withOpacity(.16);
      case PurchaseStatus.delivered:
        return Colors.green.withOpacity(.16);
      case PurchaseStatus.canceled:
      case PurchaseStatus.cancelled:
        return Colors.red.withOpacity(.14);
    }
  }

  Color _statusFg(BuildContext ctx) {
    switch (p.status) {
      case PurchaseStatus.planned:
        return Theme.of(ctx).colorScheme.onSurfaceVariant;
      case PurchaseStatus.ordered:
        return Colors.blue.shade700;
      case PurchaseStatus.bought:
        return Colors.orange.shade800;
      case PurchaseStatus.delivered:
        return Colors.green.shade800;
      case PurchaseStatus.canceled:
      case PurchaseStatus.cancelled:
        return Colors.red.shade700;
    }
  }

  String _statusLabel() {
    switch (p.status) {
      case PurchaseStatus.planned:
        return 'Planned • วางแผน';
      case PurchaseStatus.ordered:
        return 'Ordered • สั่งแล้ว';
      case PurchaseStatus.bought:
        return 'Bought • ซื้อแล้ว';
      case PurchaseStatus.delivered:
        return 'Delivered • ส่งมอบแล้ว';
      case PurchaseStatus.canceled:
      case PurchaseStatus.cancelled:
        return 'Canceled • ยกเลิก';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.currency(
      locale: 'th_TH',
      symbol: (p.currency == null || p.currency!.isEmpty) ? '฿' : p.currency!,
      decimalDigits: 2,
    );

    final amountText = (p.amountPaid != null)
        ? nf.format(p.amountPaid)
        : (p.amountEstimated != null)
        ? nf.format(p.amountEstimated)
        : '-';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        final id = p.id;
        if (id != null) context.push('/purchases/$id');
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // title + amount
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amountText,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xFF9CA3AF),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusBg(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel(),
                      style: TextStyle(
                        color: _statusFg(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (p.category?.isNotEmpty == true)
                    _TinyChip(icon: Icons.folder, label: p.category!),
                  if (p.store?.isNotEmpty == true)
                    _TinyChip(
                      icon: Icons.store_mall_directory,
                      label: p.store!,
                    ),
                ],
              ),

              if (p.note?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  p.note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TinyChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/* ===================== Errors / Empty ===================== */

class _ErrorOrAuth extends StatelessWidget {
  final Object e;
  const _ErrorOrAuth({required this.e});

  @override
  Widget build(BuildContext context) {
    if (e is AuthRequired) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Please sign in • กรุณาเข้าสู่ระบบก่อนใช้งาน',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Sign in • เข้าสู่ระบบ'),
              onPressed: () => context.push('/login'),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 8),
          const Text('Failed to load • ไม่สามารถโหลดข้อมูลได้'),
          const SizedBox(height: 4),
          Text(
            e.toString(),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQueryOrFilter;
  final VoidCallback? onClearFilters;
  const _EmptyState({required this.hasQueryOrFilter, this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    final text = hasQueryOrFilter
        ? 'No results • ไม่พบรายการตามเงื่อนไข'
        : 'No purchases yet • ยังไม่มีรายการสั่งซื้อ';
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                if (hasQueryOrFilter && onClearFilters != null)
                  OutlinedButton.icon(
                    onPressed: onClearFilters,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Clear filters • ล้างตัวกรอง'),
                  ),
                FilledButton.icon(
                  onPressed: () => context.push('/purchases/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('New • เพิ่มรายการ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ===================== Small helpers ===================== */

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
