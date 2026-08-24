// lib/widgets/alert_badge.dart
import 'package:flutter/material.dart';
import '../models/medicine_alert.dart';

class AlertBadge extends StatelessWidget {
  final MedicineAlert? alert;
  final bool dense;
  const AlertBadge({super.key, required this.alert, this.dense = true});

  @override
  Widget build(BuildContext context) {
    if (alert == null) {
      return _chip(
        context,
        label: 'ไม่ตั้งเตือน',
        color: Colors.grey.shade200,
        fg: Colors.grey.shade700,
        dense: dense,
      );
    }
    final a = alert!;
    final on = a.enabled;
    final label = on
        ? 'ON · min=${a.minQty ?? '-'} · exp=${a.expiryWindowDays ?? '-'}d'
        : 'OFF';
    return _chip(
      context,
      label: label,
      color: on ? Colors.blue.shade50 : Colors.grey.shade200,
      fg: on ? Colors.blue.shade800 : Colors.grey.shade600,
      dense: dense,
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required Color color,
    required Color fg,
    required bool dense,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: fg.withValues(alpha: .2)), // 👈 แก้ตรงนี้
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
