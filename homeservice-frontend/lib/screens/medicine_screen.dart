import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/medicine_item.dart';
import '../state/medicine_provider.dart';

import '../widgets/top_nav_bar.dart';
import '../widgets/search_bar_field.dart';
import '../widgets/last_updated_badge.dart';
import '../widgets/error_state.dart';
import '../widgets/list_empty_state.dart';

class MedicineScreen extends ConsumerStatefulWidget {
  const MedicineScreen({super.key});
  @override
  ConsumerState<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends ConsumerState<MedicineScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim();
    final asyncItems = ref.watch(medicineListProvider(query));
    const accent = Color(0xFF1F4E9E);

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: accent),
        visualDensity: VisualDensity.compact,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),

        appBar: TopNavBar(
          title: 'Medicine Stock',
          actions: const [
          ],
        ),

        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          onPressed: () => context.push('/medicine/new'),
          icon: const Icon(Icons.add),
          label: const Text('เพิ่มยาใหม่'),
        ),

        body: SafeArea(
          child: RefreshIndicator(
            color: accent,
            onRefresh: () async {
              ref.invalidate(medicineListProvider(query));
              await Future.delayed(const Duration(milliseconds: 200));
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: SearchBarField(
                            controller: _search,
                            hintText: 'ค้นหาชื่อยา...',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const LastUpdatedBadge(),
                      ],
                    ),
                  ),
                ),

                asyncItems.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: ListEmptyState(
                          title: 'ยังไม่มียาในระบบ',
                          subtitle: 'กดปุ่ม “เพิ่มยาใหม่” เพื่อสร้างรายการแรก',
                        ),
                      );
                    }

                    return SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final m = items[index];
                        return _MedicineCard(
                          item: m,
                          onTap: () => context.push('/medicine/${m.id}'),
                        );
                      }, childCount: items.length),
                    );
                  },
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, st) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorState(
                      title: 'โหลดรายการยาไม่สำเร็จ',
                      error: e,
                      onRetry: () =>
                          ref.invalidate(medicineListProvider(query)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.item, required this.onTap});

  final MedicineItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final st = item.status;
    final expired = st?.expired ?? false;
    final expirySoon = st?.expirySoon ?? false;
    final low = st?.low ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.medication_outlined, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (expired)
                          const _StatusChip(
                            label: 'หมดอายุ',
                            icon: Icons.error_outline,
                          ),
                        if (!expired && expirySoon)
                          const _StatusChip(
                            label: 'ใกล้หมดอายุ',
                            icon: Icons.schedule,
                          ),
                        if (low && !expired)
                          const _StatusChip(
                            label: 'ใกล้หมด',
                            icon: Icons.inventory_2_outlined,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (item.form != null) _InfoPill('${item.form}'),
                        if (item.unit != null) _InfoPill('หน่วย: ${item.unit}'),
                        _InfoPill('คงเหลือ ${item.stockQty}'),
                        if (item.nextExpiryDate != null)
                          _InfoPill('หมดอายุถัดไป ${item.nextExpiryDate}'),
                        if (item.locationName != null)
                          _InfoPill(item.locationName!),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Chip(
        label: Text(label),
        avatar: Icon(icon, size: 16),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
