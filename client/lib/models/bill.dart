import 'package:flutter/foundation.dart';

@immutable
class Bill {
  final String id;
  final String type;
  final String title;
  final double amount;
  final DateTime dueDate;
  final String status;
  final String? note;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Bill({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.note,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
    id: j['id'] as String,
    type: j['type'] as String,
    title: j['title'] as String,
    amount: (j['amount'] as num).toDouble(),
    dueDate: DateTime.parse(j['due_date'] as String),
    status: j['status'] as String,
    note: j['note'] as String?,
    createdBy: j['created_by'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    updatedAt: DateTime.parse(j['updated_at'] as String),
  );
}
