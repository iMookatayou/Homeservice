// lib/state/media_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../services/media_api.dart';
import '../models/media_channel.dart';
import '../models/media_post.dart';

// ✅ ใช้ Dio เฉพาะโมดูล media (จะสลับไปใช้ global dioProvider ทีหลังก็ได้)
final _mediaDioProvider = Provider<Dio>((ref) {
  // เปลี่ยน baseUrl เป็นของคุณได้ (ถ้าตัวหลักมี interceptor/token อยู่แล้ว)
  return Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
});

final mediaApiProvider = Provider<MediaApi>(
  (ref) => MediaApi(ref.watch(_mediaDioProvider)),
);

final channelsProvider = FutureProvider.family<List<MediaChannel>, String>((
  ref,
  watchId,
) async {
  return ref.watch(mediaApiProvider).listSubscriptions(watchId);
});

final mediaFeedProvider = FutureProvider.family<List<MediaPost>, String>((
  ref,
  watchId,
) async {
  return ref.watch(mediaApiProvider).listMediaFeed(watchId: watchId, limit: 20);
});

class MediaActions extends AsyncNotifier<void> {
  MediaApi get _api => ref.read(mediaApiProvider);

  @override
  Future<void> build() async {}

  Future<void> addChannelAndSubscribe({
    required String watchId,
    required String channelIdOrUrl,
    String? displayName,
  }) async {
    state = const AsyncLoading();
    final channel = await _api.createChannel(
      source: 'youtube',
      channelId: channelIdOrUrl,
      displayName: displayName ?? channelIdOrUrl,
    );
    await _api.subscribeChannel(watchId: watchId, channelUuid: channel.id);
    ref.invalidate(channelsProvider(watchId));
  }

  Future<void> removeChannel({
    required String watchId,
    required String channelUuid,
  }) async {
    state = const AsyncLoading();
    await _api.unsubscribeChannel(watchId: watchId, channelUuid: channelUuid);
    ref.invalidate(channelsProvider(watchId));
  }

  Future<void> toggleNotify({
    required String watchId,
    required String channelUuid,
  }) async {
    // no-op ตาม requirement ปัจจุบัน
  }
}

final mediaActionsProvider = AsyncNotifierProvider<MediaActions, void>(
  MediaActions.new,
);
