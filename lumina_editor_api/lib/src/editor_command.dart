import 'dart:async';
import 'package:flutter/widgets.dart';

class EditorCommand {
  final String id;
  final String label;
  final IconData? icon;
  final String shortcutLabel;
  final bool Function() canExecute;
  final FutureOr<void> Function(BuildContext?) execute;

  const EditorCommand({
    required this.id,
    required this.label,
    this.icon,
    this.shortcutLabel = '',
    required this.canExecute,
    required this.execute,
  });
}
