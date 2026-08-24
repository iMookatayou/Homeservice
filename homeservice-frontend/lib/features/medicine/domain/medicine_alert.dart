import 'package:json_annotation/json_annotation.dart';

part 'medicine_alert.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class MedicineAlert {
  final bool enabled;
  final int? minQty;
  final int? expiryWindowDays;

  MedicineAlert({required this.enabled, this.minQty, this.expiryWindowDays});

  factory MedicineAlert.fromJson(Map<String, dynamic> json) =>
      _$MedicineAlertFromJson(json);
  Map<String, dynamic> toJson() => _$MedicineAlertToJson(this);
}
