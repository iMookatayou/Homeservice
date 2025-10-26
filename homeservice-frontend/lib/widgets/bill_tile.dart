import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';

class BillTile extends StatelessWidget {
  const BillTile({super.key, required this.bill, this.onTap});
  final Bill bill;
  final VoidCallback? onTap;

  static const _green = Color(0xFF12B76A);
  static const _red = Color(0xFFF04438);
  static const _overdue = Color(0xFFB42318);
  static const _soon = Color(0xFFF79009);

  bool get _isPaid => bill.status == 'paid';

  Color _dueColor(BuildContext ctx, int d) {
    if (_isPaid) return Theme.of(ctx).colorScheme.onSurfaceVariant;
    if (d < 0) return _overdue;
    if (d <= 3) return _soon;
    return Theme.of(ctx).colorScheme.onSurfaceVariant;
  }

  String _dueText(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final d = due.difference(today).inDays;

    if (_isPaid) {
      return DateFormat('d MMM yyyy').format(dueDate);
    }
    if (d == 0) return 'Due today';
    if (d == 1) return 'Due tomorrow';
    if (d > 1 && d <= 7) return 'Due in $d days';
    if (d < 0) return '${-d} day${d == -1 ? '' : 's'} late';
    return 'Due ${DateFormat('d MMM yyyy').format(dueDate)}';
  }

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
    final cs = Theme.of(context).colorScheme;
    final money = NumberFormat.currency(locale: 'th_TH', symbol: '฿');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      bill.dueDate.year,
      bill.dueDate.month,
      bill.dueDate.day,
    );
    final d = due.difference(today).inDays;

    final chipBg = (_isPaid ? _green : _red).withOpacity(0.12);
    final chipFg = _isPaid ? _green : _red;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTight = constraints.maxWidth < 360;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Leading icon
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Hero(
                      tag: 'bill-icon-${bill.id}',
                      child: Icon(
                        _iconByType(bill.type),
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title + meta
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + Status chip (wrap เมื่อจอแคบ)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                bill.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // status chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: chipBg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: chipFg.withOpacity(0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isPaid
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 14,
                                    color: chipFg,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isPaid ? 'Paid' : 'Unpaid',
                                    style: TextStyle(
                                      color: chipFg,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Amount • Due
                        Row(
                          children: [
                            Flexible(
                              fit: FlexFit.tight,
                              child: Text(
                                money.format(bill.amount),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                            if (!isTight) ...[
                              const SizedBox(width: 8),
                              const Text('•'),
                              const SizedBox(width: 8),
                            ] else ...[
                              const SizedBox(width: 6),
                            ],
                            // Due info (ไม่กินที่: ใช้ Flexible + ellipsis)
                            Flexible(
                              fit: FlexFit.tight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!_isPaid) ...[
                                    Icon(
                                      d < 0
                                          ? Icons.error_outline
                                          : Icons.schedule,
                                      size: 16,
                                      color: _dueColor(context, d),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      _dueText(bill.dueDate),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: _dueColor(context, d),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Trailing chevron (แสดงเมื่อมี onTap)
                  if (onTap != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
