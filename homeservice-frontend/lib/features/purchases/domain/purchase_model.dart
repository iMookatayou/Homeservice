import 'package:json_annotation/json_annotation.dart';
import 'package:homeservice/models/purchase_item.dart';

part 'purchase_model.g.dart';

enum PurchaseStatus {
  @JsonValue('planned')
  planned,
  @JsonValue('ordered')
  ordered,
  @JsonValue('bought')
  bought,
  @JsonValue('delivered')
  delivered,
  @JsonValue('canceled')
  canceled,
  @JsonValue('cancelled')
  cancelled,
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class FileAttachment {
  final String id;
  final String fileName;
  final String url;
  final int? bytes;
  final String? mime;

  const FileAttachment({
    required this.id,
    required this.fileName,
    required this.url,
    this.bytes,
    this.mime,
  });

  factory FileAttachment.fromJson(Map<String, dynamic> json) =>
      _$FileAttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$FileAttachmentToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class Purchase {
  final String id;
  final String title;
  final String? note;

  final List<PurchaseItem> items;

  final double? amountEstimated;
  final double? amountPaid;

  final String? currency;
  final String? category;
  final String? store;

  final PurchaseStatus status;

  final String requesterId;
  final String? buyerId;

  final DateTime createdAt;
  final DateTime updatedAt;

  final DateTime? editableUntil;
  final List<FileAttachment>? attachments;

  const Purchase({
    required this.id,
    required this.title,
    this.note,
    required this.items,
    this.amountEstimated,
    this.amountPaid,
    this.currency,
    this.category,
    this.store,
    required this.status,
    required this.requesterId,
    this.buyerId,
    required this.createdAt,
    required this.updatedAt,
    this.editableUntil,
    this.attachments,
  });

  bool get isEditableNow =>
      editableUntil != null && DateTime.now().isBefore(editableUntil!);

  factory Purchase.fromJson(Map<String, dynamic> json) =>
      _$PurchaseFromJson(json);
  Map<String, dynamic> toJson() => _$PurchaseToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class CreatePurchasePayload {
  final String title;
  final String? note;
  final List<PurchaseItem> items;
  final double? amountEstimated;
  final String? currency;
  final String? category;
  final String? store;

  const CreatePurchasePayload({
    required this.title,
    this.note,
    this.items = const [],
    this.amountEstimated,
    this.currency,
    this.category,
    this.store,
  });

  factory CreatePurchasePayload.fromJson(Map<String, dynamic> json) =>
      _$CreatePurchasePayloadFromJson(json);
  Map<String, dynamic> toJson() => _$CreatePurchasePayloadToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class UpdatePurchasePayload {
  final String? title;
  final String? note;
  final List<PurchaseItem>? items;
  final double? amountEstimated;
  final String? category;
  final String? store;

  const UpdatePurchasePayload({
    this.title,
    this.note,
    this.items,
    this.amountEstimated,
    this.category,
    this.store,
  });

  factory UpdatePurchasePayload.fromJson(Map<String, dynamic> json) =>
      _$UpdatePurchasePayloadFromJson(json);
  Map<String, dynamic> toJson() => _$UpdatePurchasePayloadToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ProgressPayload {
  final String nextStatus; // 'ordered' | 'bought' | 'delivered'
  final double? amountPaid;

  const ProgressPayload({required this.nextStatus, this.amountPaid});

  factory ProgressPayload.fromJson(Map<String, dynamic> json) =>
      _$ProgressPayloadFromJson(json);
  Map<String, dynamic> toJson() => _$ProgressPayloadToJson(this);
}
