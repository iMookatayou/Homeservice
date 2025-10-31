// lib/screens/stock_media_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../state/media_providers.dart';
import '../widgets/media_post_tile.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/header_row.dart';
import 'manage_channels_sheet.dart';

class StockMediaScreen extends ConsumerWidget {
  const StockMediaScreen({super.key, required this.watchId});
  final String watchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(mediaFeedProvider(watchId));

    const accent = Color(0xFF1F4E9E);

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: accent),
        visualDensity: VisualDensity.compact,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),

        appBar: TopNavBar(
          title: 'Media',
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(mediaFeedProvider(watchId)),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),

        body: Column(
          children: [
            HeaderRow(
              left: const Text(
                'ฟีดคลิปล่าสุด',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              right: FilledButton.icon(
                icon: const Icon(Icons.manage_search_outlined),
                label: const Text('จัดการช่อง'),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => DraggableScrollableSheet(
                    expand: false,
                    builder: (_, scroll) => SingleChildScrollView(
                      controller: scroll,
                      child: ManageChannelsSheet(watchId: watchId),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            Expanded(
              child: feed.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(e.toString(), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () =>
                              ref.invalidate(mediaFeedProvider(watchId)),
                          icon: const Icon(Icons.refresh),
                          label: const Text('ลองอีกครั้ง'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'ยังไม่มีคลิปล่าสุด',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'กด “จัดการช่อง” เพื่อเพิ่มช่อง YouTube ที่ต้องการติดตาม',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator.adaptive(
                    onRefresh: () async {
                      await ref.refresh(mediaFeedProvider(watchId).future);
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => MediaPostTile(
                        post: items[i],
                        onTap: () => launchUrlString(
                          items[i].url,
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
