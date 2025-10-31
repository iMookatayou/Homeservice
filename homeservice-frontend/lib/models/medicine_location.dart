import 'package:json_annotation/json_annotation.dart';

part 'medicine_location.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class MedicineLocation {
  final String id;
  final String? name;

  const MedicineLocation({required this.id, this.name});

  factory MedicineLocation.fromJson(Map<String, dynamic> json) =>
      _$MedicineLocationFromJson(json);
  Map<String, dynamic> toJson() => _$MedicineLocationToJson(this);
}
