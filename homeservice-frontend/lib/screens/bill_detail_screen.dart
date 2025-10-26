import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/bill.dart';
import '../state/bills_provider.dart';

class BillDetailScreen extends ConsumerWidget {
  const BillDetailScreen({super.key, required this.bill});
  final Bill bill;

  static const _green = Color(0xFF12B76A);
  static const _red = Color(0xFFF04438);
  static const _overdue = Color(0xFFB42318);
  static const _soon = Color(0xFFF79009);

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

  // คำนวณ diff เป็นหน่วย "วัน" แบบเที่ยงคืน-เที่ยงคืน เพื่อไม่ให้ "กินวันที่"
  int _daysDiff(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(due.year, due.month, due.day);
    return d.difference(today).inDays;
  }

  Color _dueColor(BuildContext context) {
    if (bill.status == 'paid')
      return Theme.of(context).colorScheme.onSurfaceVariant;
    final d = _daysDiff(bill.dueDate);
    if (d < 0) return _overdue;
    if (d <= 3) return _soon;
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final money = NumberFormat.currency(locale: 'th_TH', symbol: '฿');
    final dtDate = DateFormat('d MMM yyyy HH:mm');
    final dtDay = DateFormat('d MMM yyyy');

    final isPaid = bill.status == 'paid';
    final statusFg = isPaid ? _green : _red;
    final statusBg = statusFg.withOpacity(0.12);

    final mark = ref.watch(billMarkPaidProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Details'),
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Card(
            elevation: 0,
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconByType(bill.type),
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bill.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _chip(
                              label: isPaid ? 'Paid' : 'Unpaid',
                              fg: statusFg,
                              bg: statusBg,
                            ),
                            _chip(
                              label: 'Due ${dtDay.format(bill.dueDate)}',
                              fg: _dueColor(context),
                              bg: _dueColor(context).withOpacity(0.08),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Amount & dates
          Card(
            elevation: 0,
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Column(
                children: [
                  _infoRow(
                    context,
                    'Amount',
                    money.format(bill.amount),
                    bold: true,
                    size: 18,
                  ),
                  _infoRow(
                    context,
                    'Status',
                    bill.status.toUpperCase(),
                    color: statusFg,
                    bold: true,
                  ),
                  _infoRow(
                    context,
                    'Due Date',
                    dtDate.format(bill.dueDate),
                    color: _dueColor(context),
                  ),
                  _infoRow(
                    context,
                    'Created At',
                    dtDate.format(bill.createdAt),
                  ),
                  _infoRow(
                    context,
                    'Updated At',
                    dtDate.format(bill.updatedAt),
                  ),
                  _infoRow(context, 'Created By', bill.createdBy),
                ],
              ),
            ),
          ),

          if (bill.note != null && bill.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: cs.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Note',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      bill.note!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          if (!isPaid)
            FilledButton.icon(
              icon: const Icon(Icons.check_circle),
              label: mark.isLoading
                  ? const Text('Processing...')
                  : const Text('Mark as Paid'),
              onPressed: mark.isLoading
                  ? null
                  : () async {
                      await ref
                          .read(billMarkPaidProvider.notifier)
                          .run(bill.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marked as paid')),
                        );
                        Navigator.of(context).pop(); // กลับไป list
                      }
                    },
            ),
        ],
      ),
    );
  }

  Widget _chip({required String label, required Color fg, required Color bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    String label,
    String value, {
    Color? color,
    double size = 14,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color ?? Theme.of(context).colorScheme.onSurface,
                fontSize: size,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
