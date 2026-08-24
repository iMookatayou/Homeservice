import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LastUpdatedBadge extends StatelessWidget {
  final DateTime? updatedAt;
  const LastUpdatedBadge({super.key, this.updatedAt});

  @override
  Widget build(BuildContext context) {
    final text = updatedAt == null
        ? 'ปรับปรุงล่าสุด: —'
        : 'ปรับปรุงล่าสุด: ${DateFormat('d MMM yyyy HH:mm').format(updatedAt!)}';

    return Row(
      children: [
        const Icon(Icons.history, size: 16),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
