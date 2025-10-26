import '../models/purchase_model.dart';
import '../models/purchase_item.dart';
import '../services/purchase_api.dart';

class PurchaseRepository {
  final PurchaseApi api;
  const PurchaseRepository(this.api);

  Future<List<Purchase>> list({int? limit, int? offset}) =>
      api.list(limit: limit, offset: offset);

  Future<Purchase> getById(String id) => api.getById(id);

  Future<Purchase> create({
    required String title,
    String? note,
    List<PurchaseItem> items = const [],
    double? amountEstimated,
    String? currency,
    String? category,
    String? store,
  }) {
    final payload = CreatePurchasePayload(
      title: title,
      note: note,
      items: items,
      amountEstimated: amountEstimated,
      currency: currency,
      category: category,
      store: store,
    );
    return api.create(payload);
  }

  Future<Purchase> update(String id, UpdatePurchasePayload payload) =>
      api.update(id, payload);

  Future<void> delete(String id) => api.delete(id);

  Future<Purchase> claim(String id) => api.claim(id);
  Future<Purchase> markOrdered(String id) =>
      api.progress(id, const ProgressPayload(nextStatus: 'ordered'));
  Future<Purchase> markBought(String id, {double? amountPaid}) => api.progress(
    id,
    ProgressPayload(nextStatus: 'bought', amountPaid: amountPaid),
  );
  Future<Purchase> markDelivered(String id) =>
      api.progress(id, const ProgressPayload(nextStatus: 'delivered'));
  Future<Purchase> cancel(String id) => api.cancel(id);
}
