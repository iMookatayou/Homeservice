import 'package:json_annotation/json_annotation.dart';

import 'medicine_item.dart';
import 'medicine_batch.dart';
import 'medicine_alert.dart';

part 'medicine_detail.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class MedicineDetail {
  final MedicineItem item;
  final List<MedicineBatch> batches;
  final MedicineAlert? alert;

  /// วันหมดอายุถัดไป (ถ้ามี)
  final DateTime? nextExpiry;

  /// เวลาอัปเดตล่าสุดของข้อมูลนี้
  final DateTime? updatedAt;

  MedicineDetail({
    required this.item,
    required this.batches,
    this.alert,
    this.nextExpiry,
    this.updatedAt,
  });

  factory MedicineDetail.fromJson(Map<String, dynamic> json) =>
      _$MedicineDetailFromJson(json);
  Map<String, dynamic> toJson() => _$MedicineDetailToJson(this);
}
