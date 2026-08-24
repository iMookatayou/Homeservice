// lib/state/medicine_provider.dart
import 'package:riverpod/riverpod.dart';

import '../services/api_client.dart'; // ApiClient + apiClientProvider
import '../services/medicine_api.dart'
    show MedicineApi, MedicineApiHttp, CreateMedicinePayload;
import '../repositories/medicine_repository.dart';
import '../models/medicine_item.dart';
import '../models/medicine_detail.dart';
import '../models/medicine_location.dart';

final medicineApiProvider = Provider<MedicineApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return MedicineApiHttp(client.dio);
});

final medicineRepoProvider = Provider<MedicineRepository>((ref) {
  final api = ref.watch(medicineApiProvider);
  return MedicineRepository(api);
});

final medicineListProvider = FutureProvider.family<List<MedicineItem>, String?>(
  (ref, q) async {
    final repo = ref.watch(medicineRepoProvider);
    return repo.list(q: (q?.isEmpty ?? true) ? null : q);
  },
);

final medicineDetailProvider = FutureProvider.family<MedicineDetail, String>((
  ref,
  id,
) async {
  final repo = ref.watch(medicineRepoProvider);
  return repo.detail(id);
});

final medicineLocationsProvider = FutureProvider<List<MedicineLocation>>((
  ref,
) async {
  final repo = ref.watch(medicineRepoProvider);
  return repo.locations();
});

final createMedicineProvider =
    FutureProvider.family<void, CreateMedicinePayload>((ref, payload) async {
      final repo = ref.read(medicineRepoProvider);
      await repo.create(payload);
      // ถ้าต้องการรีเฟรช list/locations หลังสร้าง:
      // ref.invalidate(medicineListProvider(null));
      // ref.invalidate(medicineLocationsProvider);
    });
