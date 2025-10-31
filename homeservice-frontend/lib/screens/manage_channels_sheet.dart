import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/media_providers.dart';
import '../models/media_channel.dart';

class ManageChannelsSheet extends ConsumerWidget {
  const ManageChannelsSheet({super.key, required this.watchId});
  final String watchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider(watchId));
    final ctrl = TextEditingController();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 40,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    labelText: 'YouTube Channel ID หรือ URL',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final v = ctrl.text.trim();
                  if (v.isEmpty) return;
                  await ref
                      .read(mediaActionsProvider.notifier)
                      .addChannelAndSubscribe(
                        watchId: watchId,
                        channelIdOrUrl: v,
                      );
                  ctrl.clear();
                },
                child: const Text('เพิ่ม'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          channels.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: $e'),
            ),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('ยังไม่ผูกช่องกับ Watch นี้'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return ListTile(
                        title: Text(c.displayName),
                        subtitle: Text('@${c.channelId}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => ref
                              .read(mediaActionsProvider.notifier)
                              .removeChannel(
                                watchId: watchId,
                                channelUuid: c.id,
                              ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.notifications_none),
              const SizedBox(width: 8),
              const Text('Toggle notify (ยังไม่ทำงานจริง)'),
              const Spacer(),
              Switch(value: false, onChanged: (_) {}),
            ],
          ),
        ],
      ),
    );
  }
}
