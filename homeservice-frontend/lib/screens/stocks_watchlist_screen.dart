import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/header_row.dart';

/// Watchlist แบบสตับ: เอาไว้ให้ Router ใช้งานได้เลย
/// ภายหลังค่อยเปลี่ยนเป็น list จาก provider จริง
class StocksWatchlistScreen extends StatelessWidget {
  const StocksWatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ตัวอย่าง watchId สมมติ
    final demo = const [
      {'id': '1', 'symbol': 'CK', 'name': 'CH. Karnchang PCL'},
      {'id': '2', 'symbol': 'PAUL', 'name': 'Paul Investment Watch'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: const TopNavBar(title: 'Household Stocks'),
      body: Column(
        children: [
          const HeaderRow(
            left: Text(
              'Watchlist',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            right: SizedBox.shrink(),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: demo.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final w = demo[i];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text('${w['symbol']}'),
                    subtitle: Text('${w['name']}'),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: const Text('Detail'),
                          onPressed: () => context.push('/stocks/${w['id']}'),
                        ),
                        FilledButton.icon(
                          icon: const Icon(
                            Icons.video_library_outlined,
                            size: 18,
                          ),
                          label: const Text('Media'),
                          onPressed: () =>
                              context.push('/stocks/${w['id']}/media'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
