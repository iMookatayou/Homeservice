import 'package:json_annotation/json_annotation.dart';

part 'medicine_txn.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class MedicineTxn {
  final String id;
  final String type; // 'in' | 'out' | 'adjust'
  final int qty;
  final String? note;
  final DateTime createdAt;

  MedicineTxn({
    required this.id,
    required this.type,
    required this.qty,
    this.note,
    required this.createdAt,
  });

  factory MedicineTxn.fromJson(Map<String, dynamic> json) =>
      _$MedicineTxnFromJson(json);
  Map<String, dynamic> toJson() => _$MedicineTxnToJson(this);
}
