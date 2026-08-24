// lib/widgets/media_post_tile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/media_post.dart';

class MediaPostTile extends StatelessWidget {
  const MediaPostTile({super.key, required this.post, this.onTap});

  final MediaPost post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat(
      'd MMM yyyy, HH:mm',
    ).format(post.publishedAt.toLocal());

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: post.thumbnailUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.thumbnailUrl,
                width: 72,
                height: 48,
                fit: BoxFit.cover,
              ),
            )
          : const Icon(Icons.play_circle_outline, size: 32),
      title: Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(time),
      onTap: onTap,
    );
  }
}
