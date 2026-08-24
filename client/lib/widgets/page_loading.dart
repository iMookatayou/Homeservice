import 'package:flutter/material.dart';

/// Shared "this page/list is loading" spinner. Every feature screen was
/// building its own slightly different version (plain vs .adaptive(),
/// different wrappers) — this is the one to use for a full page/list
/// load. Not for inline/non-blocking status (see LinearProgressIndicator
/// for that) or in-button submit spinners.
class PageLoading extends StatelessWidget {
  const PageLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator.adaptive());
  }
}
