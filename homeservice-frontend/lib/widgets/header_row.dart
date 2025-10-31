import 'package:flutter/material.dart';

/// วาง SearchBar ทางซ้าย + อะไรก็ได้ทางขวา (เช่น Dropdown/ปุ่ม Filters)
class HeaderRow extends StatelessWidget {
  const HeaderRow({
    super.key,
    required this.left,
    this.right,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 6),
    this.spacing = 12,
  });

  final Widget left;
  final Widget? right;
  final EdgeInsets padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: left),
          if (right != null) ...[SizedBox(width: spacing), right!],
        ],
      ),
    );
  }
}
