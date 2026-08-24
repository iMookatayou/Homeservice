// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine_batch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MedicineBatch _$MedicineBatchFromJson(Map<String, dynamic> json) =>
    MedicineBatch(
      lotNo: json['lot_no'] as String?,
      expiryDate: json['expiry_date'] == null
          ? null
          : DateTime.parse(json['expiry_date'] as String),
      qty: (json['qty'] as num).toInt(),
    );

Map<String, dynamic> _$MedicineBatchToJson(MedicineBatch instance) =>
    <String, dynamic>{
      'lot_no': instance.lotNo,
      'expiry_date': instance.expiryDate?.toIso8601String(),
      'qty': instance.qty,
    };
