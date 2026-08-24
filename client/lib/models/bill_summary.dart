import 'package:flutter/foundation.dart';

@immutable
class BillSummary {
  final String type;
  final double totalAmount;
  final double totalPaid;
  final double totalUnpaid;
  final int count;

  const BillSummary({
    required this.type,
    required this.totalAmount,
    required this.totalPaid,
    required this.totalUnpaid,
    required this.count,
  });

  factory BillSummary.fromJson(Map<String, dynamic> j) => BillSummary(
    type: j['type'] as String,
    totalAmount: (j['total_amount'] as num).toDouble(),
    totalPaid: (j['total_paid'] as num).toDouble(),
    totalUnpaid: (j['total_unpaid'] as num).toDouble(),
    count: j['count'] as int,
  );
}
