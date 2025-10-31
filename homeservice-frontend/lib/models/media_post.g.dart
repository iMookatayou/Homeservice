// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_post.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MediaPost _$MediaPostFromJson(Map<String, dynamic> json) => MediaPost(
  id: json['id'] as String,
  channelId: json['channel_id'] as String,
  source: json['source'] as String,
  externalId: json['external_id'] as String,
  title: json['title'] as String,
  url: json['url'] as String,
  thumbnailUrl: json['thumbnail_url'] as String,
  publishedAt: DateTime.parse(json['published_at'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$MediaPostToJson(MediaPost instance) => <String, dynamic>{
  'id': instance.id,
  'channel_id': instance.channelId,
  'source': instance.source,
  'external_id': instance.externalId,
  'title': instance.title,
  'url': instance.url,
  'thumbnail_url': instance.thumbnailUrl,
  'published_at': instance.publishedAt.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
};
