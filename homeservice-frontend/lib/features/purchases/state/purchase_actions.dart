import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/purchase_model.dart';
import 'purchase_providers.dart';

/// Payload สำหรับ create (ตามสเปค STEP 1)
class CreatePurchasePayload {
  final String title;
  final String? note;
  final double? amountEstimated;
  final String currency;

  const CreatePurchasePayload({
    required this.title,
    this.note,
    this.amountEstimated,
    this.currency = 'THB',
  });
}

/// Provider action: create purchase แล้ว refresh list
final createPurchaseProvider =
    FutureProvider.family<Purchase, CreatePurchasePayload>((
      ref,
      payload,
    ) async {
      final repo = ref.read(purchaseRepoProvider);

      // เรียกด้วย named params ให้ตรงกับ signature ของ repo.create(...)
      final created = await repo.create(
        title: payload.title,
        note: payload.note,
        amountEstimated: payload.amountEstimated,
        currency: payload.currency,
      );

      // refresh list ทันทีตาม Acceptance
      ref.invalidate(purchasesListProvider);
      return created;
    });

class UploadAttachmentPayload {
  final String id;
  final File file;
  final String? filename;
  const UploadAttachmentPayload({
    required this.id,
    required this.file,
    this.filename,
  });
}

final uploadAttachmentProvider =
    FutureProvider.family<Purchase, UploadAttachmentPayload>((
      ref,
      payload,
    ) async {
      final repo = ref.read(purchaseRepoProvider);
      final updated = await repo.uploadAttachment(
        payload.id,
        payload.file,
        filename: payload.filename,
      );
      ref.invalidate(purchaseDetailProvider(payload.id));
      return updated;
    });

class DeleteAttachmentPayload {
  final String id;
  final String fileId;
  const DeleteAttachmentPayload({required this.id, required this.fileId});
}

final deleteAttachmentProvider =
    FutureProvider.family<Purchase, DeleteAttachmentPayload>((
      ref,
      payload,
    ) async {
      final repo = ref.read(purchaseRepoProvider);
      final updated = await repo.deleteAttachment(payload.id, payload.fileId);
      ref.invalidate(purchaseDetailProvider(payload.id));
      return updated;
    });
