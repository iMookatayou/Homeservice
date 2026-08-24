// lib/widgets/batch_tile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medicine_batch.dart';
import 'qty_badge.dart' as q; // 👈 ใส่ prefix

class BatchTile extends StatelessWidget {
  final MedicineBatch b;
  const BatchTile({super.key, required this.b});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy');
    final exp = b.expiryDate != null ? dateFmt.format(b.expiryDate!) : '-';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE7ECF4)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.lotNo?.isNotEmpty == true
                      ? 'Lot ${b.lotNo}'
                      : 'ไม่มีเลขล็อต',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.event, size: 16),
                    const SizedBox(width: 4),
                    Text('หมดอายุ: $exp'),
                  ],
                ),
              ],
            ),
          ),
          q.qtyBadge(b.qty),
        ],
      ),
    );
  }
}
