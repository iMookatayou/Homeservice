import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/header_row.dart';

class StockDetailScreen extends StatelessWidget {
  const StockDetailScreen({super.key, required this.watchId});
  final String watchId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: const TopNavBar(title: 'Stock Detail'),
      body: Column(
        children: [
          HeaderRow(
            left: Text(
              'Watch #$watchId',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            right: FilledButton.icon(
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('Media'),
              onPressed: () => context.push('/stocks/$watchId/media'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: const [
                Card(
                  elevation: 0,
                  child: ListTile(
                    title: Text('Overview (stub)'),
                    subtitle: Text('ใส่กราฟ/สรุป/คำอธิบายหุ้นที่นี่ภายหลัง'),
                  ),
                ),
                SizedBox(height: 8),
                Card(
                  elevation: 0,
                  child: ListTile(
                    title: Text('Positions (stub)'),
                    subtitle: Text('ตารางถือครอง/ราคาเฉลี่ย ฯลฯ'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
