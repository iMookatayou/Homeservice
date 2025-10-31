// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine_txn.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MedicineTxn _$MedicineTxnFromJson(Map<String, dynamic> json) => MedicineTxn(
  id: json['id'] as String,
  type: json['type'] as String,
  qty: (json['qty'] as num).toInt(),
  note: json['note'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$MedicineTxnToJson(MedicineTxn instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'qty': instance.qty,
      'note': instance.note,
      'created_at': instance.createdAt.toIso8601String(),
    };
