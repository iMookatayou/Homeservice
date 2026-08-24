import 'package:json_annotation/json_annotation.dart';

part 'purchase_item.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class PurchaseItem {
  final String name;
  final double? qty;
  final String? unit;
  final double? price;

  const PurchaseItem({required this.name, this.qty, this.unit, this.price});

  factory PurchaseItem.fromJson(Map<String, dynamic> json) =>
      _$PurchaseItemFromJson(json);
  Map<String, dynamic> toJson() => _$PurchaseItemToJson(this);
}
