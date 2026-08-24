// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MedicineItem _$MedicineItemFromJson(Map<String, dynamic> json) => MedicineItem(
  id: json['id'] as String,
  name: json['name'] as String,
  form: json['form'] as String?,
  unit: json['unit'] as String?,
  category: json['category'] as String?,
  stockQty: (json['stock_qty'] as num).toDouble(),
  nextExpiryDate: json['next_expiry_date'] == null
      ? null
      : DateTime.parse(json['next_expiry_date'] as String),
  locationName: json['location_name'] as String?,
  status: json['status'] == null
      ? null
      : MedicineItemStatus.fromJson(json['status'] as Map<String, dynamic>),
);

Map<String, dynamic> _$MedicineItemToJson(MedicineItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'form': instance.form,
      'unit': instance.unit,
      'category': instance.category,
      'stock_qty': instance.stockQty,
      'next_expiry_date': instance.nextExpiryDate?.toIso8601String(),
      'location_name': instance.locationName,
      'status': instance.status?.toJson(),
    };

MedicineItemStatus _$MedicineItemStatusFromJson(Map<String, dynamic> json) =>
    MedicineItemStatus(
      low: json['low'] as bool,
      expirySoon: json['expiry_soon'] as bool,
      expired: json['expired'] as bool,
    );

Map<String, dynamic> _$MedicineItemStatusToJson(MedicineItemStatus instance) =>
    <String, dynamic>{
      'low': instance.low,
      'expiry_soon': instance.expirySoon,
      'expired': instance.expired,
    };
