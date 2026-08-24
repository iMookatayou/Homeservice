import 'package:flutter/material.dart';

class ListEmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData? icon;

  /// Center-aligned, no card background — for embedding directly on a
  /// page (e.g. inside a scrollable list area). Default is a bordered
  /// white card, left-aligned.
  final bool centered;

  const ListEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.icon,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 48, color: cs.outline),
          const SizedBox(height: 12),
        ],
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: centered ? TextAlign.center : TextAlign.start,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: centered ? TextAlign.center : TextAlign.start,
          ),
        ],
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    );

    if (centered) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: content));
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7ECF4)),
      ),
      child: content,
    );
  }
}
