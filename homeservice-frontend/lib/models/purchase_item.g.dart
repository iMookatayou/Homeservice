// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PurchaseItem _$PurchaseItemFromJson(Map<String, dynamic> json) => PurchaseItem(
  name: json['name'] as String,
  qty: (json['qty'] as num?)?.toDouble(),
  unit: json['unit'] as String?,
  price: (json['price'] as num?)?.toDouble(),
);

Map<String, dynamic> _$PurchaseItemToJson(PurchaseItem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'qty': instance.qty,
      'unit': instance.unit,
      'price': instance.price,
    };
