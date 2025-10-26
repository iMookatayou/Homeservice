import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../state/bills_provider.dart';
import '../models/bill_summary.dart';

class BillsSummaryScreen extends ConsumerWidget {
  const BillsSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(billsSummaryProvider);
    final currency = NumberFormat.currency(locale: 'th_TH', symbol: '฿');

    return Scaffold(
      appBar: AppBar(title: const Text('Bills Summary'), elevation: 0),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('โหลดสรุปไม่สำเร็จ\n$e'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('ยังไม่มีข้อมูลสรุปบิล'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _SummaryCard(item: items[i], currency: currency),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.item, required this.currency});
  final BillSummary item;
  final NumberFormat currency;

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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_iconByType(item.type), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // type + count
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.type,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'x${item.count}',
                          style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // totals
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _pill(
                        'total',
                        currency.format(item.totalAmount),
                        Colors.black87,
                      ),
                      _pill(
                        'paid',
                        currency.format(item.totalPaid),
                        Colors.green.shade700,
                      ),
                      _pill(
                        'unpaid',
                        currency.format(item.totalUnpaid),
                        Colors.red.shade600,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: color, fontSize: 13),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
