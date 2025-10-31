// lib/services/media_api.dart
import 'package:dio/dio.dart';
import '../models/media_channel.dart';
import '../models/media_post.dart';

class MediaApi {
  final Dio dio;
  MediaApi(this.dio);

  // ===== Channels (global) =====
  Future<MediaChannel> createChannel({
    required String source, // 'youtube'
    required String channelId,
    required String displayName,
  }) async {
    final res = await dio.post(
      '/api/v1/media/channels',
      data: {
        'source': source,
        'channel_id': channelId,
        'display_name': displayName,
      },
    );
    return MediaChannel.fromJson(res.data);
  }

  Future<List<MediaChannel>> getChannelList() async {
    final res = await dio.get('/api/v1/media/channels');
    final data = (res.data as List).cast<Map<String, dynamic>>();
    return data.map(MediaChannel.fromJson).toList();
  }

  Future<void> deleteChannel(String channelUuid) async {
    await dio.delete('/api/v1/media/channels/$channelUuid');
  }

  // ===== Watch-scoped =====
  static const _watchBase = '/api/v1/stock-watches';

  Future<void> subscribeChannel({
    required String watchId,
    required String channelUuid,
  }) async {
    await dio.post(
      '$_watchBase/$watchId/channels',
      data: {'channel_id': channelUuid},
    );
  }

  Future<List<MediaChannel>> listSubscriptions(String watchId) async {
    final res = await dio.get('$_watchBase/$watchId/channels');
    final data = (res.data as List).cast<Map<String, dynamic>>();
    return data.map(MediaChannel.fromJson).toList();
  }

  Future<void> unsubscribeChannel({
    required String watchId,
    required String channelUuid,
  }) async {
    await dio.delete('$_watchBase/$watchId/channels/$channelUuid');
  }

  Future<List<MediaPost>> listMediaFeed({
    required String watchId,
    int limit = 20,
    String? cursor,
  }) async {
    final res = await dio.get(
      '$_watchBase/$watchId/media',
      queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
    );

    // รองรับทั้งรูปแบบ {items: [...]} หรือ [...] ตรง ๆ
    final body = res.data;
    final list = (body is Map && body['items'] is List)
        ? (body['items'] as List)
        : (body as List);

    return list
        .map((e) => MediaPost.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
