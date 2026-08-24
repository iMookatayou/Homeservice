import 'package:json_annotation/json_annotation.dart';

part 'medicine_batch.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class MedicineBatch {
  final String? lotNo;
  final DateTime? expiryDate;
  final int qty;

  MedicineBatch({this.lotNo, this.expiryDate, required this.qty});

  factory MedicineBatch.fromJson(Map<String, dynamic> json) =>
      _$MedicineBatchFromJson(json);
  Map<String, dynamic> toJson() => _$MedicineBatchToJson(this);
}
