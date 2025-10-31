// lib/state/medicine_actions.dart
import 'package:riverpod/riverpod.dart';

import '../repositories/medicine_repository.dart';
import '../services/medicine_api.dart';
import '../models/medicine_alert.dart'; // 👈 เพิ่มอันนี้
import 'medicine_provider.dart';

final createMedicineProvider =
    FutureProvider.family<void, CreateMedicinePayload>((ref, p) async {
      await ref.read(medicineRepoProvider).create(p);
      ref.invalidate(medicineListProvider);
    });

final txnOutProvider =
    FutureProvider.family<void, (String id, TxnOutPayload p)>((
      ref,
      args,
    ) async {
      await ref.read(medicineRepoProvider).txnOut(args.$1, args.$2);
      ref.invalidate(medicineDetailProvider(args.$1));
      ref.invalidate(medicineListProvider);
    });

final txnInProvider = FutureProvider.family<void, (String id, TxnInPayload p)>((
  ref,
  args,
) async {
  await ref.read(medicineRepoProvider).txnIn(args.$1, args.$2);
  ref.invalidate(medicineDetailProvider(args.$1));
  ref.invalidate(medicineListProvider);
});

final alertUpdateProvider =
    FutureProvider.family<void, (String id, MedicineAlert a)>((
      ref,
      args,
    ) async {
      await ref.read(medicineRepoProvider).putAlert(args.$1, args.$2);
      ref.invalidate(medicineDetailProvider(args.$1));
    });
