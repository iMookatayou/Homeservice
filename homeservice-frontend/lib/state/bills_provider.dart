import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../state/purchase_providers.dart' show purchasesDioProvider;

import '../models/bill.dart';
import '../models/bill_summary.dart';
import '../repositories/bill_repository.dart';

/// ===== Dio (ปรับให้ชี้ตัวจริงในโปรเจกต์คุณ) =====
final dioProvider = Provider<Dio>((ref) {
  return ref.watch(
    purchasesDioProvider,
  ); // reuse baseUrl + auth interceptors เดิม
});

final billRepositoryProvider = Provider<BillRepository>(
  (ref) => BillRepository(ref.watch(dioProvider)),
);

/// ===== Filter/Search (Notifier-based) =====
enum BillsStatusFilter { all, paid, unpaid }

class BillsQueryController extends Notifier<String> {
  @override
  String build() => ''; // ค่าเริ่มต้น

  void set(String v) => state = v;
  void clear() => state = '';
}

final billsQueryProvider = NotifierProvider<BillsQueryController, String>(
  BillsQueryController.new,
);

class BillsStatusFilterController extends Notifier<BillsStatusFilter> {
  @override
  BillsStatusFilter build() => BillsStatusFilter.all;

  void set(BillsStatusFilter f) => state = f;
}

final billsStatusFilterProvider =
    NotifierProvider<BillsStatusFilterController, BillsStatusFilter>(
      BillsStatusFilterController.new,
    );

/// ===== List (watch query + filter) =====
final billsProvider = FutureProvider.autoDispose<List<Bill>>((ref) async {
  final repo = ref.watch(billRepositoryProvider);
  final q = ref.watch(billsQueryProvider);
  final f = ref.watch(billsStatusFilterProvider);

  String? status;
  switch (f) {
    case BillsStatusFilter.paid:
      status = 'paid';
      break;
    case BillsStatusFilter.unpaid:
      status = 'unpaid';
      break;
    case BillsStatusFilter.all:
      status = null;
      break;
  }

  return repo.list(query: q.isEmpty ? null : q, status: status);
});

/// ===== Summary =====
final billsSummaryProvider = FutureProvider.autoDispose<List<BillSummary>>((
  ref,
) async {
  return ref.watch(billRepositoryProvider).summary();
});

/// ===== Create (AsyncNotifier) =====
class BillCreateController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String type,
    required String title,
    required double amount,
    required DateTime dueDate,
    required String status,
    String? note,
  }) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(billRepositoryProvider)
          .create(
            type: type,
            title: title,
            amount: amount,
            dueDate: dueDate,
            status: status,
            note: note,
          );
      ref.invalidate(billsProvider);
      ref.invalidate(billsSummaryProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final billCreateProvider =
    AsyncNotifierProvider.autoDispose<BillCreateController, void>(
      BillCreateController.new,
    );

/// ===== Mark paid (AsyncNotifier) =====
class BillMarkPaidController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> run(String id) async {
    state = const AsyncLoading();
    try {
      await ref.read(billRepositoryProvider).markPaid(id);
      ref.invalidate(billsProvider);
      ref.invalidate(billsSummaryProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final billMarkPaidProvider =
    AsyncNotifierProvider.autoDispose<BillMarkPaidController, void>(
      BillMarkPaidController.new,
    );
