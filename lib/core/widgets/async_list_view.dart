import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'empty_state.dart';

/// Renders a streamed list with the loading/empty/error handling every
/// feature screen needs, so screens only supply how one item looks.
class AsyncListView<T> extends StatelessWidget {
  const AsyncListView({
    super.key,
    required this.asyncValue,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyMessage,
    this.padding,
  });

  final AsyncValue<List<T>> asyncValue;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final IconData emptyIcon;
  final String emptyMessage;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(icon: emptyIcon, message: emptyMessage);
        }
        return ListView.builder(
          padding: padding,
          itemCount: items.length,
          itemBuilder: (context, index) => itemBuilder(context, items[index], index),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}
