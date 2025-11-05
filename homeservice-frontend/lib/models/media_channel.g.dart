// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_channel.dart';

MediaChannel _$MediaChannelFromJson(Map<String, dynamic> json) => MediaChannel(
  id: json['id'] as String,
  source: json['source'] as String,
  channelId: json['channel_id'] as String,
  displayName: json['display_name'] as String,
  url: json['url'] as String,
  createdBy: json['created_by'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$MediaChannelToJson(MediaChannel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'source': instance.source,
      'channel_id': instance.channelId,
      'display_name': instance.displayName,
      'url': instance.url,
      'created_by': instance.createdBy,
      'created_at': instance.createdAt.toIso8601String(),
    };
