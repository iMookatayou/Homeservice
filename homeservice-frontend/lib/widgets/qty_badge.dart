import 'package:flutter/material.dart';

/// ใช้เป็นฟังก์ชัน (ตามที่คุณเรียก `q.qtyBadge(...)`)
Widget qtyBadge(int qty, {int low = 10, bool dense = false}) {
  final bool isLow = qty <= low;
  final EdgeInsets p = dense
      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
      : const EdgeInsets.symmetric(horizontal: 10, vertical: 6);

  return Container(
    padding: p,
    decoration: BoxDecoration(
      color: isLow
          ? Colors.orange.withOpacity(.15)
          : Colors.green.withOpacity(.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: isLow ? Colors.orange : Colors.green),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isLow ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          size: dense ? 14 : 16,
        ),
        const SizedBox(width: 6),
        Text('คงเหลือ $qty'),
      ],
    ),
  );
}
