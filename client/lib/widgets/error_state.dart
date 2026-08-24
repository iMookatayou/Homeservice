import 'package:flutter/material.dart';

class ErrorState extends StatelessWidget {
  final String title;
  final Object? error;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.title, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (error != null)
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 12),
          if (onRetry != null)
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
        ],
      ),
    );
  }
}
