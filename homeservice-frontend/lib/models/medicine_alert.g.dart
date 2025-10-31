// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine_alert.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MedicineAlert _$MedicineAlertFromJson(Map<String, dynamic> json) =>
    MedicineAlert(
      enabled: json['enabled'] as bool,
      minQty: (json['min_qty'] as num?)?.toInt(),
      expiryWindowDays: (json['expiry_window_days'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MedicineAlertToJson(MedicineAlert instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'min_qty': instance.minQty,
      'expiry_window_days': instance.expiryWindowDays,
    };
