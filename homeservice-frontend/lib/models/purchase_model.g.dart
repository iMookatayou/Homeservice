// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FileAttachment _$FileAttachmentFromJson(Map<String, dynamic> json) =>
    FileAttachment(
      id: json['id'] as String,
      fileName: json['file_name'] as String,
      url: json['url'] as String,
      bytes: (json['bytes'] as num?)?.toInt(),
      mime: json['mime'] as String?,
    );

Map<String, dynamic> _$FileAttachmentToJson(FileAttachment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'file_name': instance.fileName,
      'url': instance.url,
      'bytes': instance.bytes,
      'mime': instance.mime,
    };

Purchase _$PurchaseFromJson(Map<String, dynamic> json) => Purchase(
  id: json['id'] as String,
  title: json['title'] as String,
  note: json['note'] as String?,
  items: (json['items'] as List<dynamic>)
      .map((e) => PurchaseItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  amountEstimated: (json['amount_estimated'] as num?)?.toDouble(),
  amountPaid: (json['amount_paid'] as num?)?.toDouble(),
  currency: json['currency'] as String?,
  category: json['category'] as String?,
  store: json['store'] as String?,
  status: $enumDecode(_$PurchaseStatusEnumMap, json['status']),
  requesterId: json['requester_id'] as String,
  buyerId: json['buyer_id'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  editableUntil: json['editable_until'] == null
      ? null
      : DateTime.parse(json['editable_until'] as String),
  attachments: (json['attachments'] as List<dynamic>?)
      ?.map((e) => FileAttachment.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$PurchaseToJson(Purchase instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'note': instance.note,
  'items': instance.items.map((e) => e.toJson()).toList(),
  'amount_estimated': instance.amountEstimated,
  'amount_paid': instance.amountPaid,
  'currency': instance.currency,
  'category': instance.category,
  'store': instance.store,
  'status': _$PurchaseStatusEnumMap[instance.status]!,
  'requester_id': instance.requesterId,
  'buyer_id': instance.buyerId,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'editable_until': instance.editableUntil?.toIso8601String(),
  'attachments': instance.attachments?.map((e) => e.toJson()).toList(),
};

const _$PurchaseStatusEnumMap = {
  PurchaseStatus.planned: 'planned',
  PurchaseStatus.ordered: 'ordered',
  PurchaseStatus.bought: 'bought',
  PurchaseStatus.delivered: 'delivered',
  PurchaseStatus.canceled: 'canceled',
  PurchaseStatus.cancelled: 'cancelled',
};

CreatePurchasePayload _$CreatePurchasePayloadFromJson(
  Map<String, dynamic> json,
) => CreatePurchasePayload(
  title: json['title'] as String,
  note: json['note'] as String?,
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => PurchaseItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  amountEstimated: (json['amount_estimated'] as num?)?.toDouble(),
  currency: json['currency'] as String?,
  category: json['category'] as String?,
  store: json['store'] as String?,
);

Map<String, dynamic> _$CreatePurchasePayloadToJson(
  CreatePurchasePayload instance,
) => <String, dynamic>{
  'title': instance.title,
  'note': instance.note,
  'items': instance.items.map((e) => e.toJson()).toList(),
  'amount_estimated': instance.amountEstimated,
  'currency': instance.currency,
  'category': instance.category,
  'store': instance.store,
};

UpdatePurchasePayload _$UpdatePurchasePayloadFromJson(
  Map<String, dynamic> json,
) => UpdatePurchasePayload(
  title: json['title'] as String?,
  note: json['note'] as String?,
  items: (json['items'] as List<dynamic>?)
      ?.map((e) => PurchaseItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  amountEstimated: (json['amount_estimated'] as num?)?.toDouble(),
  category: json['category'] as String?,
  store: json['store'] as String?,
);

Map<String, dynamic> _$UpdatePurchasePayloadToJson(
  UpdatePurchasePayload instance,
) => <String, dynamic>{
  'title': instance.title,
  'note': instance.note,
  'items': instance.items?.map((e) => e.toJson()).toList(),
  'amount_estimated': instance.amountEstimated,
  'category': instance.category,
  'store': instance.store,
};

ProgressPayload _$ProgressPayloadFromJson(Map<String, dynamic> json) =>
    ProgressPayload(
      nextStatus: json['next_status'] as String,
      amountPaid: (json['amount_paid'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ProgressPayloadToJson(ProgressPayload instance) =>
    <String, dynamic>{
      'next_status': instance.nextStatus,
      'amount_paid': instance.amountPaid,
    };
