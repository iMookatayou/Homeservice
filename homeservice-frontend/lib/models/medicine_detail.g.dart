// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MedicineDetail _$MedicineDetailFromJson(Map<String, dynamic> json) =>
    MedicineDetail(
      item: MedicineItem.fromJson(json['item'] as Map<String, dynamic>),
      batches: (json['batches'] as List<dynamic>)
          .map((e) => MedicineBatch.fromJson(e as Map<String, dynamic>))
          .toList(),
      alert: json['alert'] == null
          ? null
          : MedicineAlert.fromJson(json['alert'] as Map<String, dynamic>),
      nextExpiry: json['next_expiry'] == null
          ? null
          : DateTime.parse(json['next_expiry'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$MedicineDetailToJson(MedicineDetail instance) =>
    <String, dynamic>{
      'item': instance.item.toJson(),
      'batches': instance.batches.map((e) => e.toJson()).toList(),
      'alert': instance.alert?.toJson(),
      'next_expiry': instance.nextExpiry?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
