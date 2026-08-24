// lib/repositories/medicine_repository.dart
import '../models/medicine_item.dart';
import '../models/medicine_detail.dart';
import '../services/medicine_api.dart';
import '../models/medicine_alert.dart';
import '../models/medicine_location.dart';

class MedicineRepository {
  final MedicineApi _api;

  // cache เบา ๆ (optional)
  final Map<String, MedicineDetail> _detailCache = {};

  MedicineRepository(this._api);

  Future<List<MedicineItem>> list({String? q}) {
    return _api.list(q: q);
  }

  Future<MedicineDetail> detail(String id) async {
    if (_detailCache.containsKey(id)) return _detailCache[id]!;
    final d = await _api.detail(id);
    _detailCache[id] = d;
    return d;
  }

  Future<void> create(CreateMedicinePayload p) async {
    await _api.create(p);
  }

  Future<void> txnOut(String id, TxnOutPayload p) async {
    await _api.txnOut(id, p);
    _detailCache.remove(id);
  }

  Future<void> txnIn(String id, TxnInPayload p) async {
    await _api.txnIn(id, p);
    _detailCache.remove(id);
  }

  Future<void> putAlert(String id, MedicineAlert a) async {
    await _api.putAlert(id, a);
    _detailCache.remove(id);
  }

  Future<List<MedicineLocation>> locations() {
    return _api.locations();
  }
}
