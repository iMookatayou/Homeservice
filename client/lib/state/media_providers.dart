// lib/state/media_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_channel.dart';
import '../models/media_post.dart';
import '../services/api_client.dart';
import '../services/media_api.dart';

final mediaApiProvider = Provider<MediaApi>(
  (ref) => MediaApi(ref.watch(apiClientProvider).dio),
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
    try {
      final channel = await _api.createChannel(
        source: 'youtube',
        channelId: channelIdOrUrl,
        displayName: displayName ?? channelIdOrUrl,
      );
      await _api.subscribeChannel(watchId: watchId, channelUuid: channel.id);
      ref.invalidate(channelsProvider(watchId));
      ref.invalidate(mediaFeedProvider(watchId));
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> removeChannel({
    required String watchId,
    required String channelUuid,
  }) async {
    state = const AsyncLoading();
    try {
      await _api.unsubscribeChannel(
        watchId: watchId,
        channelUuid: channelUuid,
      );
      ref.invalidate(channelsProvider(watchId));
      ref.invalidate(mediaFeedProvider(watchId));
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> toggleNotify({
    required String watchId,
    required String channelUuid,
  }) async {
    state = const AsyncData(null);
  }
}

final mediaActionsProvider = AsyncNotifierProvider<MediaActions, void>(
  MediaActions.new,
);
