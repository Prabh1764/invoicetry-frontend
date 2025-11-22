import 'package:flutter/material.dart';

enum TagType {
  draft,
  pending,
  paid,
  overdue,
}

class TagChip extends StatelessWidget {
  final String label;
  final TagType type;

  const TagChip({
    super.key,
    required this.label,
    required this.type,
  });

  Color get _backgroundColor {
    switch (type) {
      case TagType.draft:
        return Colors.grey.shade200;
      case TagType.pending:
        return Colors.orange.shade100;
      case TagType.paid:
        return Colors.green.shade100;
      case TagType.overdue:
        return Colors.red.shade100;
    }
  }

  Color get _textColor {
    switch (type) {
      case TagType.draft:
        return Colors.grey.shade800;
      case TagType.pending:
        return Colors.orange.shade900;
      case TagType.paid:
        return Colors.green.shade900;
      case TagType.overdue:
        return Colors.red.shade900;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

