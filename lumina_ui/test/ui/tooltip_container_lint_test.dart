import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// shadcn's `Tooltip` draws its builder's widget as-is: without a
/// `TooltipContainer` the tooltip is bare text with no background, border or
/// padding. Every tooltip builder in the editor must wrap its content.
void main() {
  test('every Tooltip builder wraps its content in TooltipContainer', () {
    final offenders = <String>[];
    final arrow = RegExp(r'tooltip:\s*\(\s*\w+\s*\)\s*=>\s*(\S[^\n]*)');
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final m = arrow.firstMatch(lines[i]);
        if (m == null) continue;
        // The expression may continue on the next line (`=>\n  Text(...)`).
        final expr = m.group(1)!.trim().isEmpty && i + 1 < lines.length ? lines[i + 1].trim() : m.group(1)!;
        if (!expr.contains('TooltipContainer')) offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(offenders, isEmpty, reason: 'wrap these tooltips in TooltipContainer:\n${offenders.join('\n')}');
  });
}
