import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../state/purchase_providers.dart';
import '../models/purchase_model.dart';

class PurchaseDetailScreen extends ConsumerWidget {
  final String id;
  const PurchaseDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDetail = ref.watch(purchaseDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Detail')),
      body: asyncDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: 'โหลดไม่สำเร็จ: $e',
          onRetry: () => ref.invalidate(purchaseDetailProvider(id)),
        ),
        data: (p) => RefreshIndicator(
          onRefresh: () async => ref.refresh(purchaseDetailProvider(id).future),
          child: _DetailView(p: p),
        ),
      ),
      bottomNavigationBar: asyncDetail.maybeWhen(
        orElse: () => null,
        data: (p) => _BottomActions(
          p: p,
          onAdvance: () {
            // TODO: ต่อ action “Next status” ของคุณ
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ยังไม่ได้ต่อ API: advance status')),
            );
          },
          onEdit: () {
            // TODO: ไปหน้าแก้ไข
          },
          onAttach: () {
            // TODO: เปิดตัวเลือกแนบไฟล์/รูป/วิดีโอ
          },
        ),
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  final Purchase p;
  const _DetailView({required this.p});

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.currency(
      locale: 'th_TH',
      symbol: p.currency == null || p.currency!.isEmpty ? '฿' : p.currency!,
      decimalDigits: 2,
    );

    final items = p.items ?? [];
    final lineTotal = items.fold<double>(
      0,
      (sum, it) => sum + ((it.price ?? 0.0) * ((it.qty ?? 0).toDouble())),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(p: p, nf: nf),
        const SizedBox(height: 12),
        if (p.note?.isNotEmpty == true) ...[
          _SectionCard(
            title: 'บันทึก',
            child: Text(p.note!, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(height: 12),
        ],
        _SectionCard(
          title: 'รายการสินค้า',
          trailing: Text(
            '${items.length} รายการ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          child: items.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '— ไม่มีรายการ —',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : Column(
                  children: [
                    ...items.map(
                      (it) => _LineItemTile(
                        name: it.name,
                        unit: it.unit,
                        qty: it.qty,
                        price: it.price,
                        currencySymbol:
                            p.currency == null || p.currency!.isEmpty
                            ? '฿'
                            : p.currency!,
                        nf: nf,
                      ),
                    ),
                    const Divider(height: 24),
                    _KeyValueRow(
                      label: 'รวมตามรายการ',
                      value: nf.format(lineTotal),
                      isEmphasis: true,
                    ),
                    if (p.amountEstimated != null) ...[
                      const SizedBox(height: 6),
                      _KeyValueRow(
                        label: 'ประมาณการ',
                        value: nf.format(p.amountEstimated),
                      ),
                    ],
                    if (p.amountPaid != null) ...[
                      const SizedBox(height: 6),
                      _KeyValueRow(
                        label: 'จ่ายจริง',
                        value: nf.format(p.amountPaid),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 24),
        // เผื่อคุณต่อ “ไฟล์แนบ/รูป/วิดีโอ” ภายหลัง
        // _SectionCard(title: 'ไฟล์แนบ', child: _AttachmentsGrid(files: p.files)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Purchase p;
  final NumberFormat nf;
  const _SummaryCard({required this.p, required this.nf});

  Color _statusBg(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    switch (p.status) {
      case PurchaseStatus.planned:
        return cs.surfaceVariant;
      case PurchaseStatus.ordered:
        return Colors.blue.withOpacity(.15);
      case PurchaseStatus.bought:
        return Colors.amber.withOpacity(.2);
      case PurchaseStatus.delivered:
        return Colors.green.withOpacity(.2);
      case PurchaseStatus.canceled:
      case PurchaseStatus.cancelled:
        return Colors.red.withOpacity(.2);
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
    // ปรับไทย/อังกฤษตามต้องการ
    switch (p.status) {
      case PurchaseStatus.planned:
        return 'วางแผน';
      case PurchaseStatus.ordered:
        return 'สั่งซื้อแล้ว';
      case PurchaseStatus.bought:
        return 'ซื้อแล้ว';
      case PurchaseStatus.delivered:
        return 'ส่งมอบแล้ว';
      case PurchaseStatus.canceled:
      case PurchaseStatus.cancelled:
        return 'ยกเลิก';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBg(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _statusFg(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (p.category?.isNotEmpty == true)
                  _InfoChip(icon: Icons.folder, label: p.category!),
                if (p.store?.isNotEmpty == true)
                  _InfoChip(icon: Icons.store_mall_directory, label: p.store!),
                if (p.amountEstimated != null)
                  _InfoChip(
                    icon: Icons.calculate_outlined,
                    label: 'ประมาณ ${nf.format(p.amountEstimated)}',
                  ),
                if (p.amountPaid != null)
                  _InfoChip(
                    icon: Icons.payments_outlined,
                    label: 'จ่ายจริง ${nf.format(p.amountPaid)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _LineItemTile extends StatelessWidget {
  final String name;
  final String? unit;
  final num? qty;
  final double? price;
  final String currencySymbol;
  final NumberFormat nf;

  const _LineItemTile({
    required this.name,
    required this.unit,
    required this.qty,
    required this.price,
    required this.currencySymbol,
    required this.nf,
  });

  @override
  Widget build(BuildContext context) {
    final q = (qty ?? 0);
    final subtitle = [
      'จำนวน: ${qty == null ? "-" : q.toString()}',
      if ((unit ?? '').isNotEmpty) unit!,
      if (price != null) '• ${nf.format(price)} / หน่วย',
    ].join(' ');

    final lineSum = price == null ? null : (price! * q.toDouble());

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: lineSum == null
          ? null
          : Text(
              nf.format(lineSum),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isEmphasis;
  const _KeyValueRow({
    required this.label,
    required this.value,
    this.isEmphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: t.bodyMedium)),
        Text(
          value,
          style: (isEmphasis ? t.titleMedium : t.bodyMedium)?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final Purchase p;
  final VoidCallback onAdvance;
  final VoidCallback onEdit;
  final VoidCallback onAttach;
  const _BottomActions({
    required this.p,
    required this.onAdvance,
    required this.onEdit,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onAdvance,
                icon: const Icon(Icons.fast_forward),
                label: const Text('Next status'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onAttach,
              tooltip: 'แนบไฟล์/รูป',
              icon: const Icon(Icons.attachment),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('แก้ไข'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
        ],
      ),
    );
  }
}
