import 'package:flutter/foundation.dart'; // kReleaseMode (ถ้าจะใช้ logic เพิ่มภายหลัง)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../state/contractors_provider.dart';
import '../models/contractor.dart';

class ContractorsScreen extends ConsumerStatefulWidget {
  const ContractorsScreen({super.key});
  @override
  ConsumerState<ContractorsScreen> createState() => _ContractorsScreenState();
}

class _ContractorsScreenState extends ConsumerState<ContractorsScreen> {
  final _search = TextEditingController();

  final _types = const [
    {'label': 'Electrician', 'value': 'electrician'},
    {'label': 'Plumber', 'value': 'plumber'},
    {'label': 'Carpenter', 'value': 'carpenter'},
    {'label': 'HVAC', 'value': 'hvac'},
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  double _km(int meters) => meters / 1000.0;

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(contractorsListProvider);
    final filter = ref.watch(contractorFilterProvider);
    final locAsync = ref.watch(currentLatLngProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contractors'),
        centerTitle: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Location status (เฉพาะกรณี error/ปิดสิทธิ์เท่านั้น) ───────────────
          _LocationBanner(
            locAsync: locAsync,
            onRefresh: () {
              ref.invalidate(currentLatLngProvider);
              ref.invalidate(contractorsListProvider);
            },
          ),

          // ── Search ────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'ค้นหา (เช่น electrician, plumber, ชื่อร้าน)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                ref.read(contractorFilterProvider.notifier).setQuery(v.trim());
                ref.invalidate(contractorsListProvider);
              },
            ),
          ),
          const SizedBox(height: 12),

          // ── Type chips ───────────────────────────────────────────────────────
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, i) {
                final t = _types[i];
                final selected = filter.type == t['value'];
                return ChoiceChip(
                  label: Text(t['label']!),
                  selected: selected,
                  onSelected: (_) {
                    ref
                        .read(contractorFilterProvider.notifier)
                        .setType(selected ? null : t['value'] as String);
                    ref.invalidate(contractorsListProvider);
                  },
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _types.length,
            ),
          ),
          const SizedBox(height: 12),

          // ── Radius slider (2–15 กม.) ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('ระยะรัศมี'),
                Expanded(
                  child: Slider(
                    value: _km(filter.radius).clamp(2.0, 15.0),
                    min: 2,
                    max: 15,
                    divisions: 13,
                    label: '${_km(filter.radius).round()} กม.',
                    onChanged: (v) {
                      ref
                          .read(contractorFilterProvider.notifier)
                          .setRadius((v * 1000).round());
                    },
                    onChangeEnd: (_) => ref.invalidate(contractorsListProvider),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text('${_km(filter.radius).round()} กม.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),

          // ── List ─────────────────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: listAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'เกิดข้อผิดพลาด: $e',
                    textAlign: TextAlign.center,
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return _EmptyState(
                      onExpand: () {
                        ref
                            .read(contractorFilterProvider.notifier)
                            .setRadius(15000);
                        ref.invalidate(contractorsListProvider);
                      },
                    );
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ContractorCard(c: list[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.locAsync, required this.onRefresh});
  final AsyncValue<({double lat, double lng})> locAsync;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return locAsync.when(
      // แสดง progress บาง ๆ ตอนกำลังดึงพิกัด
      loading: () => const LinearProgressIndicator(minHeight: 2),

      // แสดงเฉพาะกรณี service ปิด / permission deny
      error: (e, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Card(
          color: const Color(0xFFFFF4CC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.location_off),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ยังไม่ได้เปิดบริการตำแหน่ง หรือไม่ได้อนุญาตการเข้าถึง\n'
                    'โปรดเปิด Location แล้วกดรีเฟรช',
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('ตั้งค่า'),
                  onPressed: () async {
                    await Geolocator.openLocationSettings();
                    await Geolocator.openAppSettings();
                    onRefresh();
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      // ถ้าได้พิกัดแล้ว: ไม่ต้องโชว์อะไร (ซ่อน banner)
      data: (_) => const SizedBox.shrink(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onExpand});
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48),
          const SizedBox(height: 8),
          const Text('ไม่พบนายช่างในรัศมีที่เลือก'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.expand_circle_down),
            label: const Text('ขยายรัศมีเป็น 15 กม.'),
            onPressed: onExpand,
          ),
        ],
      ),
    );
  }
}

class _ContractorCard extends StatelessWidget {
  const _ContractorCard({required this.c});
  final Contractor c;

  @override
  Widget build(BuildContext context) {
    final km = (((c.distanceM ?? 0) / 1000)).toStringAsFixed(1);
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text('$km กม.'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              c.types.join(' • '),
              style: const TextStyle(color: Colors.black54),
            ),
            if ((c.address?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 4),
              Text(
                c.address ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (c.phone != null && c.phone!.trim().isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.call),
                    label: const Text('โทร'),
                    onPressed: () async {
                      final uri = Uri(scheme: 'tel', path: c.phone!.trim());
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text('เปิดแผนที่'),
                  onPressed: () async {
                    final name = Uri.encodeComponent(c.name);
                    final geo = Uri.parse('geo:${c.lat},${c.lng}?q=$name');
                    final apple = Uri.parse(
                      'https://maps.apple.com/?ll=${c.lat},${c.lng}&q=$name',
                    );
                    final gmaps = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${c.lat},${c.lng}',
                    );

                    if (await canLaunchUrl(geo)) {
                      await launchUrl(
                        geo,
                        mode: LaunchMode.externalApplication,
                      );
                    } else if (await canLaunchUrl(apple)) {
                      await launchUrl(
                        apple,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      await launchUrl(
                        gmaps,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
