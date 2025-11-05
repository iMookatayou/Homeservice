import 'package:json_annotation/json_annotation.dart';
part 'media_channel.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class MediaChannel {
  final String id;
  final String source; // 'youtube'
  final String channelId; // UCxxxx
  final String displayName;
  final String url;
  final String createdBy;
  final DateTime createdAt;

  MediaChannel({
    required this.id,
    required this.source,
    required this.channelId,
    required this.displayName,
    required this.url,
    required this.createdBy,
    required this.createdAt,
  });

  factory MediaChannel.fromJson(Map<String, dynamic> j) =>
      _$MediaChannelFromJson(j);
  Map<String, dynamic> toJson() => _$MediaChannelToJson(this);
}
