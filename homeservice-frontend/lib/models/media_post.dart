import 'package:json_annotation/json_annotation.dart';
part 'media_post.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class MediaPost {
  final String id;
  final String channelId;
  final String source; // 'youtube'
  final String externalId; // videoId
  final String title;
  final String url;
  final String thumbnailUrl;
  final DateTime publishedAt;
  final DateTime createdAt;

  MediaPost({
    required this.id,
    required this.channelId,
    required this.source,
    required this.externalId,
    required this.title,
    required this.url,
    required this.thumbnailUrl,
    required this.publishedAt,
    required this.createdAt,
  });

  factory MediaPost.fromJson(Map<String, dynamic> j) => _$MediaPostFromJson(j);
  Map<String, dynamic> toJson() => _$MediaPostToJson(this);
}
